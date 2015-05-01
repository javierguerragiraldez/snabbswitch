module(...,package.seeall)
local Link = {}     -- OOP method table

local debug = _G.developer_debug

local ffi = require("ffi")
local C = ffi.C

local packet = require("core.packet")
require("core.packet_h")
require("core.link_h")

local band = require("bit").band

local size = C.LINK_RING_SIZE         -- NB: Huge slow-down if this is not local
max        = C.LINK_MAX_PACKETS

function new (receiving_app)
   return ffi.new("struct link", {receiving_app = receiving_app})
end

function Link:receive ()
--   if debug then assert(not self:empty(), "receive on empty link") end
   local pkt = self.packets[self.read]
   self.read = band(self.read + 1, size - 1)

   self.stats.rxpackets = self.stats.rxpackets + 1
   self.stats.rxbytes   = self.stats.rxbytes + pkt.length
   return pkt
end

function Link:front ()
   return (self.read ~= self.write) and self.packets[self.read] or nil
end

function Link:transmit (pkt)
--   assert(pkt)
   if self:full() then
      self.stats.txdrop = self.stats.txdrop + 1
      pkt:free()
   else
      self.packets[self.write] = pkt
      self.write = band(self.write + 1, size - 1)
      self.stats.txpackets = self.stats.txpackets + 1
      self.stats.txbytes   = self.stats.txbytes + pkt.length
      self.has_new_data = true
   end
end

-- Return true if the ring is empty.
function Link:empty ()
   return self.read == self.write
end

-- Return true if the ring is full.
function Link:full ()
   return band(self.write + 1, size - 1) == self.read
end

-- Return the number of packets that are ready for read.
function Link:nreadable ()
   if self.read > self.write then
      return self.write + size - self.read
   else
      return self.write - self.read
   end
end

function Link:nwritable ()
   return max - self:nreadable()
end

function Link:stats ()
   return self.stats
end

function selftest ()
   print("selftest: link")
   local lnk = new()
   local pkt = packet.allocate()
   assert(lnk.stats.txpackets == 0 and lnk:empty() == true  and lnk:full() == false)
   assert(lnk:nreadable() == 0)
   lnk:transmit(pkt)
   assert(lnt.stats.txpackets == 1 and lnk:empty() == false and lnk:full() == false)
   for i = 1, max-2 do
      lnk:transmit(pkt)
   end
   assert(lnk.stats.txpackets == max-1 and lnk:empty() == false and lnk:full() == false)
   assert(lnk:nreadable() == lnk.stats.txpackets)
   lnk:transmit(pkt)
   assert(lnk.stats.txpackets == max   and lnk:empty() == false and lnk:full() == true)
   lnk:transmit(pkt)
   assert(lnk.stats.txpackets == max and lnk.stats.txdrop == 1)
   assert(not lnk:empty() and lnk:full())
   while not lnk:empty() do
      lnk:receive()
   end
   assert(lnk.stats.rxpackets == max)
   print("selftest OK")
end

ffi.metatype('struct link', {__index = Link})
