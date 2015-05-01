module(...,package.seeall)
local Packet = {}

local debug = _G.developer_debug

local ffi = require("ffi")
local C = ffi.C

local freelist = require("core.freelist")
local lib      = require("core.lib")
local memory   = require("core.memory")
local freelist_add, freelist_remove, freelist_nfree = freelist.add, freelist.remove, freelist.nfree

require("core.packet_h")

local packet_t = ffi.typeof("struct packet")
local packet_ptr_t = ffi.typeof("struct packet *")
local packet_size = ffi.sizeof(packet_t)
local header_size = 8
local max_payload = tonumber(C.PACKET_PAYLOAD_SIZE)

-- Freelist containing empty packets ready for use.
local max_packets = 1e5
local packet_allocation_step = 1000
local packets_allocated = 0
local packets_fl = freelist.new("struct packet *", max_packets)

-- Return an empty packet.
function allocate ()
   if freelist_nfree(packets_fl) == 0 then
      preallocate_step()
   end
   return freelist_remove(packets_fl)
end

-- Create a new empty packet.
function new_packet ()
   local p = ffi.cast(packet_ptr_t, memory.dma_alloc(packet_size))
   p.length = 0
   return p
end

-- Create an exact copy of a packet.
function Packet:clone ()
   local pkt2 = allocate()
   ffi.copy(pkt2, self, self.length)
   pkt2.length = self.length
   return pkt2
end

-- Append data to the end of a packet.
function Packet:append (ptr, len)
   assert(self.length + len <= max_payload, "packet payload overflow")
   ffi.copy(self.data + self.length, ptr, len)
   self.length = self.length + len
   return self
end

-- Prepend data to the start of a packet.
function Packet:prepend (ptr, len)
   assert(self.length + len <= max_payload, "packet payload overflow")
   C.memmove(self.data + len, self.data, self.length) -- Move the existing payload
   ffi.copy(self.data, ptr, len)                -- Fill the gap
   self.length = self.length + len
   return self
end

-- Move packet data to the left. This shortens the packet by dropping
-- the header bytes at the front.
function Packet:shiftleft (bytes)
   C.memmove(self.data, self.data+bytes, self.length-bytes)
   self.length = self.length - bytes
end

-- Conveniently create a packet by copying some existing data.
function from_pointer (ptr, len) return allocate():append(ptr, len) end
function from_string (d)         return from_pointer(d, #d) end

-- Free a packet that is no longer in use.
local function free_internal (pkt)
   pkt.length = 0
   freelist_add(packets_fl, pkt)
end

function Packet:free ()
   engine.frees = engine.frees + 1
   engine.freebytes = engine.freebytes + self.length
   -- Calculate bits of physical capacity required for packet on 10GbE
   -- Account for minimum data size and overhead of CRC and inter-packet gap
   engine.freebits = engine.freebits + (math.max(self.length, 46) + 4 + 5) * 8
   free_internal(self)
end

-- Return pointer to packet data.
function Packet:data () return self.data end

-- Return packet data length.
function Packet:length () return self.length end

function preallocate_step()
   if _G.developer_debug then
      assert(packets_allocated + packet_allocation_step <= max_packets)
   end

   for i=1, packet_allocation_step do
      free_internal(new_packet(), true)
   end
   packets_allocated = packets_allocated + packet_allocation_step
   packet_allocation_step = 2 * packet_allocation_step
end

ffi.metatype(packet_t, {__index = Packet})
