
module(..., package.seeall)

local ffi       = require("ffi")
local C         = ffi.C
local S         = require('syscall')
local pci       = require("lib.hardware.pci")
local vfio      = require("lib.hardware.vfio")
local bit       = require('bit')
local lib       = require("core.lib")
local link      = require("core.link")
local packet    = require("core.packet")
local checksum  = require("lib.checksum")
local gvring    = require('apps.vguest.guest_vring')
require('lib.virtio.virtio_h')
local band = bit.band

local function fstruct(def)
   local struct = {}
   local offset = 0
   for ct, fld in def:gmatch('([%a_][%w_]*)%s+([%a_][%w_]*);') do
      ct = ffi.typeof(ct)
      struct[fld] = {
         fieldname = fld,
         ct = ct,
         size = ffi.sizeof(ct),
         offset = offset,
      }
      offset = offset + struct[fld].size
   end
   return struct, offset
end

local function fieldrd(field, fd)
   local buf = ffi.typeof('$ [1]', field.ct)()
   local r, err = fd:pread(buf, field.size, field.offset)
   if not r then error(err) end
   return buf[0]
end

local function fieldwr(field, fd, val)
   local buf = ffi.typeof('$ [1]', field.ct)()
   buf[0] = val
   assert(fd:seek(field.offset))
   local r, err = fd:write(buf, field.size)
   if not r then error(err) end
   return buf[0]
end

local function openBar(fd, struct)
   local err = nil
   if type(fd) == 'string' then
      print ('fd A:', fd)
      fd, err = S.open(fd, 'rdwr')
      if not fd then error(err) end
      print ('fd B:', fd)
   end
   if type(fd) == 'number' then
      print ('fd A:', fd)
      fd = S.t.fd(fd)
      print ('fd B:', fd)
   end
   return setmetatable ({
      fd = fd,
      struct = struct,
      close = function(self) return self.fd:close() end,
   }, {
      __index = function (self, key)
         return fieldrd(self.struct[key], self.fd)
      end,
      __newindex = function (self, key, value)
         return fieldwr(self.struct[key], self.fd, value)
      end,
   })
end

virtio_pci_bar0 = fstruct[[
   uint32_t host_features;
   uint32_t guest_features;
   uint32_t queue_pfn;
   uint16_t queue_num;
   uint16_t queue_sel;
   uint16_t queue_notify;
   uint8_t status;
   uint8_t isr;
   uint16_t config_vector;
   uint16_t queue_vector;
]]

local _qnbuf=ffi.new('uint16_t[1]')
local function notify(fd, qn)
   _qnbuf[0] = qn
   fd:pwrite(_qnbuf, 2, 16)
end

function mapBar(fname, ct)
   ct = ffi.typeof(ct)
   local fd, err = S.open(fname, 'rdwr')
   if not fd then error(err) end

   local st = S.fstat(fd)
   print ('stat size', st.size)

   print ('sizeof ct', ffi.sizeof(ct))
   local mem, err = S.mmap(nil, st.size, 'read, write', 'shared', fd)
   fd:close()
   if mem == nil then error("mmap failed: " .. tostring(err)) end
   mappings[pointer_to_number(mem)] = size
   return ffi.cast(ffi.typeof("$&", ct), mem)
end

-- function mapBar(device, n, ct)
--    local mem, fd = pci.map_pci_memory(device, n)
--    print ('mem:', mem, 'fd:', fd)
--    return ffi.cast(ffi.typeof("$&", ct), mem)
-- end

vfio.init_vfio_modules{'1af4 1000'}

function mapBar(device, n, ct)
   local devinfo = vfio.device_info(device)
   vfio.setup_vfio(device, true)
   C.show_device_info(vfio.get_vfio_fd(device))

   vfio.map_memory_to_iommu(nil, 1024*1024)
   local mem = vfio.map_pci_memory(device, n)
   print ('mem:', mem)
   vfio.set_bus_master(device, true)
   return ffi.cast(ffi.typeof("$&", ct), mem)
end

function openVfioBar(device)
   local devinfo = vfio.device_info(device)
   vfio.setup_vfio(device, true)
   local fd = vfio.get_vfio_fd(device)
   C.show_device_info(fd)
   C.mask_irq(fd, 0, 0)

   return openBar(pci.path(device..'/resource0'), virtio_pci_bar0)
end

VGdev = {}
VGdev.__index = VGdev


function VGdev:new(args)
   local min_features = 0 -- C.VIRTIO_F_VERSION_1?
   local want_features = C.VIRTIO_NET_F_CSUM
                        + C.VIRTIO_NET_F_MAC
--                         + C.VIRTIO_RING_F_EVENT_IDX
--                         + C.VIRTIO_F_VERSION_1
   pci.unbind_device_from_linux (args.pciaddr)

--    local bar = openBar(pci.path(args.pciaddr..'/resource0'), virtio_pci_bar0)
--    local bar = mapBar(pci.path(args.pciaddr..'/resource0'), ffi.typeof[[
--    local bar = mapBar(args.pciaddr, 0, ffi.typeof[[
--       struct {
--          uint32_t host_features;
--          uint32_t guest_features;
--          uint32_t queue_pfn;
--          uint16_t queue_num;
--          uint16_t queue_sel;
--          uint16_t queue_notify;
--          uint8_t status;
--          uint8_t isr;
--          uint16_t config_vector;
--          uint16_t queue_vector;
--       }
--    ]])
   local bar = openVfioBar(args.pciaddr)

--    for k,v in pairs(virtio_pci_bar0) do
--       print (string.format('%s: %X', v.fieldname, bar[v.fieldname]))
--    end

   bar.status = 0           -- reset device
   bar.status = bit.bor(bar.status, 1)           -- acknowledge
   -- check something
   bar.status = bit.bor(bar.status, 2)           -- driver
   local features = bar.host_features
   print ('host_features', features)
   if bit.band(features, min_features) ~= min_features then
      bar.status = bit.bor(bar.status, 128)      -- failure
      bar:close()
      return nil, "doesn't provide minimum features"
   end
   print ('ask features:', bit.band(features, want_features))
   bar.guest_features = bit.band(features, want_features)
   bar.status = bit.bor(bar.status, 8)           -- features_ok
   print ('got features: ', bar.host_features, bar.guest_features)
   if bit.band(bar.status, 8) ~= 8 then
      bar.status = bit.bor(bar.status, 128)      -- failure
      bar:close()
      return nil, "feature set wasn't accepted by device"
   end

   print ("enumerating queues...")
   local vqs = {}
   for qn = 0, 16 do
      bar.queue_sel = qn
      local queue_size = bar.queue_num
      if queue_size == 0 then break end

      print (string.format('queue %d: size: %d', qn, queue_size))
      local vring = gvring.allocate_vring(bar.queue_num, 1, 0)
      vqs[qn] = vring
      bar.queue_pfn = bit.rshift(vring.vring_physaddr, 12)      -- VIRTIO_PCI_QUEUE_ADDR_SHIFT
      print (string.format('avail.flags: %d\tused.flags: %d',
         vring.vring.avail.flags, vring.vring.used.flags))
   end

   if not(vqs[0] and vqs[1]) then
      bar.status = bit.bor(bar.status, 128)      -- failure
      bar:close()
      return nil, "missing required virtqueues"
   end

   bar.status = bit.bor(bar.status, 4)           -- driver_ok

   return setmetatable({
      bar = bar,
      vqs = vqs,
      notified_sent = 0,
   }, self)
end


function VGdev:close()
   for qn, vq in pairs(self.vqs) do
      self.bar.queue_sel = qn
      self.bar.queue_pfn = 0
   end
   self.bar:close()
end


function VGdev:can_transmit()
   return self.vqs[1]:can_add()
end

local pk_header = ffi.new([[
   struct {
      uint8_t flags;
      uint8_t gso_type;
      int16_t hdr_len;
      int16_t gso_size;
      int16_t csum_start;
      int16_t csum_offset;
//    int16_t num_buffers;    // only if MRG_RXBUF feature active
   }
]])
function VGdev:transmit(p)
   -- TODO: prepend header (5.1.6.2)
--    p:dump()
   ffi.fill(pk_header, ffi.sizeof(pk_header))
   local ethertype = ffi.cast('uint16_t*', p.data+12)[0]
   if ethertype == 0xDD86 or ethertype == 0x0080 then
      local startoffset = C.prepare_packet(p.data+14, p.length-14)
      if startoffset ~= nil then
--          print ('prepared', startoffset, startoffset[0], startoffset[1])
         pk_header.flags = 1      -- VIRTIO_NET_HDR_F_NEEDS_CSUM
         pk_header.csum_start = 14+startoffset[0]
         pk_header.csum_offset = startoffset[1]
      end
   end
   p:prepend(pk_header, ffi.sizeof(pk_header))
   self.vqs[1]:add(p)
end


function VGdev:sync_transmit(do_notify)
   local txq = self.vqs[1]
   -- notify the device
--    do
--       local avail_idx = txq.vring.avail.idx
--       local avail_event = txq.vring.used.avail_event_idx
--       local old_idx = self.notified_sent
-- --       if txq.vring.avail.idx ~= self.notified_sent then
--       if band(avail_idx - avail_event -1, 0xFFFF) < band(avail_idx - old_idx) then
   if do_notify then
         notify(self.bar.fd, 1)           -- self.bar.queue_notify = 1
   end
--          self.notified_sent = txq.vring.avail.idx
--       end
--    end

   -- free transmitted packets
   while txq:more_used() do
      local p = txq:get()
      if p ~= nil then p:free() end
   end
end


function VGdev:can_receive()
--    io.write('k')
   local rq = self.vqs[0]
--    io.write(string.format('(%d-%d)', rq.vring.used.idx, rq.last_used_idx))
   local r = self.vqs[0]:more_used()
--    io.write(string.format('[%s]', tostring(r)))
   return r
end


function VGdev:receive()
   io.write('v')
   local p = self.vqs[0]:get()
   p:dump()
   p:shiftleft(ffi.sizeof(pk_header))
   return p
end


function VGdev:sync_receive(new_buffers)
   if new_buffers then
      io.write('n')
      notify(self.bar.fd, 0)
   end
end


function VGdev:can_add_receive_buffer()
   return self.vqs[0]:can_add()
end


function VGdev:add_receive_buffer(p)
--    io.write('r')
   self.vqs[0]:add(p, ffi.sizeof(p.data))
end
