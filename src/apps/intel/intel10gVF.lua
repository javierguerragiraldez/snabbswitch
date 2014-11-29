

local ffi      = require "ffi"
local C        = ffi.C
local lib      = require("core.lib")
local pci      = require("lib.hardware.pci")
local register = require("lib.hardware.register")
local index_set = require("lib.index_set")
local macaddress = require("lib.macaddress")

local bits, bitset = lib.bits, lib.bitset
local band, bor, lshift = bit.band, bit.bor, bit.lshift
local packet_ref = packet.ref


local NUM_DESCRIPTORS = 32 * 1024

local M = {}; M.__index = M

function new(pciaddress)
   local dev = { pciaddress = pciaddress, -- PCI device address
                 err = nil,
                 fd = false,       -- File descriptor for PCI memory
                 r = {},           -- Configuration registers
                 s = {},           -- Statistics registers
                 txdesc = 0,     -- Transmit descriptors (pointer)
                 txdesc_phy = 0, -- Transmit descriptors (physical address)
                 txpackets = {},   -- Tx descriptor index -> packet mapping
                 tdh = 0,          -- Cache of transmit head (TDH) register
                 tdt = 0,          -- Cache of transmit tail (TDT) register
                 rxdesc = 0,     -- Receive descriptors (pointer)
                 rxdesc_phy = 0, -- Receive descriptors (physical address)
                 rxbuffers = {},   -- Rx descriptor index -> buffer mapping
                 rdh = 0,          -- Cache of receive head (RDH) register
                 rdt = 0,          -- Cache of receive tail (RDT) register
                 rxnext = 0,        -- Index of next buffer to receive
                 prev_ctx_desc_a = 0,
                 prev_ctx_desc_b = 0,
                 offloadflags = 0ULL,
              }
   return setmetatable(dev, M_sf)
end


function M:open ()
   pci.set_bus_master(self.pciaddress, true)
   self.base, self.fd = pci.map_pci_memory(self.pciaddress, 0)
   register.define(vf_registers_desc, self.r, self.base)
   register.define_array(vf_queue_registers_desc, self.r, self.base)
   self.txpackets = ffi.new("struct packet *[?]", NUM_DESCRIPTORS)
   self.rxbuffers = ffi.new("struct buffer *[?]", NUM_DESCRIPTORS)
   return self:init()
end

function M:close()
   if self.fd then
      pci.close_pci_resource(self.fd)
      self.fd = false
   end
end


function M:init ()
   return self
      :init_dma_memory()
      :vf_reset()
      :init_receive()
      :init_transmit()
      :wait_enable()
end


function M:init_dma_memory ()
   self.rxdesc, self.rxdesc_phy =
      memory.dma_alloc(NUM_DESCRIPTORS * ffi.sizeof(rxdesc_t))
   self.txdesc, self.txdesc_phy =
      memory.dma_alloc(NUM_DESCRIPTORS * ffi.sizeof(txdesc_t))
   -- Add bounds checking
   self.rxdesc = lib.bounds_checked(rxdesc_t, self.rxdesc, 0, NUM_DESCRIPTORS)
   self.txdesc = lib.bounds_checked(txdesc_t, self.txdesc, 0, NUM_DESCRIPTORS)
   return self
end


function M:vf_reset()
   self:stop_vf()
   self.r.VFCTRL(bits{DeviceReset=26})
   self.r.VFSTATUS()

   do
      local reset_ok = false
      for _ = 1,200 do
         if self:mbx_has_reset() then
            reset_ok = true
            break
         end
      end
      if not reset_ok then
         self.err = 'reset timeout'
         return self
      end
   end

   self:mbx_send(0x01, nil, nil)        -- VF_RESET
   C.usleep(10000)

   do
      local msg = self:mbx_read()
      if msg.type ~= 0x80000001 and msg.type ~= 0x40000001 then
         self.err = 'invalid MAC addr'
         return self
      end
      -- copy addr from msg[1:]
   end

   return self
end


function M:stop_vf()
   for q = 0, MAX_QUEUE_NUM do
      self.r.VFRXDCTL[q]:clr(bits{Enable=25})
   end
   self.r.VFSTATUS()        -- flush
end


function M:init_receive()
end


vf_registers_desc = [[
VFCTRL      0x00000 -               RW VF Device Control
VFSTATUS    0x00008 -               RO VF Device Status
]]

vf_queue_registers_desc = [[
VFRXDCTL    0x01028 +0x40*0..7      RW Receive Descriptor Control
]]
