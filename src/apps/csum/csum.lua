

local ffi = require "ffi"
local C = ffi.C
local app = require("core.app")
local basic_apps = require("apps.basic.basic_apps")
local band, bor, bnot = bit.band, bit.bor, bit.bnot
local checksum = require("lib.checksum")


local PACKET_CSUM_FLAGS = C.PACKET_CSUM_VALID + C.PACKET_NEEDS_CSUM
local uint16p_t = ffi.typeof('uint16_t *')

local Checksum = {
   zone = 'csum',
   _name = "CPU-based checksum"
}
Checksum.__index = Checksum


function Checksum:new()
   local o = setmetatable({
      csum_added = 0,
      csum_total = 0,
      chk_valid = 0,
      chk_drop = 0,
      chk_pass = 0,
   }, self)

   return o
end


function Checksum:report()
   print ('inner -> outer')
   print ('\tchecksum added:', self.csum_added)
   print ('\ttotal:', self.csum_total)
   print ('outer -> inner')
   print ('\tvalid packets:', self.chk_valid)
   print ('\tdropped packets:', self.chk_drop)
   print ('\tpassthrough packets:', self.chk_pass)
end


function Checksum:push()
   do -- inner -> outer: add checksum
      local l_in = self.input.inner
      local l_out = self.output.outer
      if l_in and l_out then
         while not link.empty(l_in) and not link.full(l_out) do
            local p = link.receive(l_in)
            if band(p.flags, PACKET_CSUM_FLAGS) == C.PACKET_NEEDS_CSUM
               and p.csum_start > 0 and p.csum_offset > 0
            then
               local b = p.data + p.csum_start
               ffi.cast(uint16p_t, b+p.csum_offset)[0] = checksum.ipsum(b, p.length - p.csum_start, 0)

               p.flags = bor(band(p.flags, bnot(C.PACKET_NEEDS_CSUM)), C.PACKET_CSUM_VALID)
               self.csum_added = self.csum_added + 1
            end
            link.transmit(l_out, p)
            self.csum_total = self.csum_total + 1
         end
      end
   end

   do -- outer -> inner: verify checksum, drops invalid packets
      local l_in = self.input.outer
      local l_out = self.output.inner
      if l_in and l_out then
         while not link.empty(l_in) and not link.full(l_out) do
            local p = link.receive(l_in)
            if band(p.flags, PACKET_CSUM_FLAGS) == C.PACKET_NEEDS_CSUM
               and p.csum_start > 0 and p.csum_offset > 0
            then
               local b = p.data + p.csum_start
               if 0 == checksum.ipsum(b, p.length - p.csum_start, 0) then
                  p.flags = bor(band(p.flags, bnot(C.PACKET_NEEDS_CSUM)), C.PACKET_CSUM_VALID)
                  link.transmit(l_out, p)
                  self.chk_valid = self.chk_valid + 1
               else
                  packet.free(p)
                  self.chk_drop = self.chk_drop + 1
               end
            else
               link.transmit(l_out, p)
               self.chk_pass = self.chk_pass + 1
            end
         end
      end
   end
end



function Checksum.selftest()
   print ('add checksums')
   local c = config.new()
   config.app(c, 'source', basic_apps.Source)
   config.app(c, 'checksum', Checksum)
   config.app(c, 'sink', basic_apps.Sink)
   config.link(c, 'source.out -> checksum.inner')
   config.link(c, 'checksum.outer -> sink.in')
   engine.configure(c)

   engine.main({duration = 1, report={showlinks=true, showapps=true}})

   engine.configure (config.new())
   print ('verify checksums')
   local c = config.new()
   config.app(c, 'source', basic_apps.Source)
   config.app(c, 'checksum', Checksum)
   config.app(c, 'sink', basic_apps.Sink)
   config.link(c, 'source.out -> checksum.outer')
   config.link(c, 'checksum.inner -> sink.in')
   engine.configure(c)

   engine.main({duration = 1, report={showlinks=true, showapps=true}})
end

return Checksum
