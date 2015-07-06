module(...,package.seeall)

local debug = _G.developer_debug

local ffi = require("ffi")
local C = ffi.C
local S = require('syscall')

local freelist = require("core.freelist")
local lib      = require("core.lib")
local memory   = require("core.memory")
local stats    = require('core.stats')
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
local packets_fl = nil
local stats_count = nil


function postfork()
   packets_fl = freelist.new('struct packet *', max_packets)
   stats_count = stats()
end

-- Return an empty packet.
function allocate ()
   if packets_fl == nil then print ('allocate() without freelist'); error('dead') end
--    print ('allocate')
--    print ('packets_fl', packets_fl)
--    print ('freelist.nfree A', packets_fl.nfree)
   if freelist_nfree(packets_fl) == 0 then
--       print ('allocate(), zero free')
      preallocate_step()
   end
--    print ('freelist.nfree B', packets_fl.nfree)
   return freelist_remove(packets_fl)
end

-- Create a new empty packet.
function new_packet ()
--    local pid = S.getpid()
--    print ('new_packet', pid)
--    local p = ffi.cast(packet_ptr_t, memory.dma_alloc(packet_size))
   local ptr, phy, bys = memory.dma_alloc(packet_size)
--    print ('new_packet B:', pid, ptr, phy, bys)
   local p = ffi.cast(packet_ptr_t, ptr)
--    print ('new_packet C:', pid, p)
   p.length = 0
--    print ('done new_packet', p, pid)
   return p
end

-- Create an exact copy of a packet.
function clone (p)
   local p2 = allocate()
   ffi.copy(p2, p, p.length)
   p2.length = p.length
   return p2
end

-- Append data to the end of a packet.
function append (p, ptr, len)
   assert(p.length + len <= max_payload, "packet payload overflow")
   ffi.copy(p.data + p.length, ptr, len)
   p.length = p.length + len
   return p
end

-- Prepend data to the start of a packet.
function prepend (p, ptr, len)
   assert(p.length + len <= max_payload, "packet payload overflow")
   C.memmove(p.data + len, p.data, p.length) -- Move the existing payload
   ffi.copy(p.data, ptr, len)                -- Fill the gap
   p.length = p.length + len
   return p
end

-- Move packet data to the left. This shortens the packet by dropping
-- the header bytes at the front.
function shiftleft (p, bytes)
   C.memmove(p.data, p.data+bytes, p.length-bytes)
   p.length = p.length - bytes
end

-- Conveniently create a packet by copying some existing data.
function from_pointer (ptr, len) return append(allocate(), ptr, len) end
function from_string (d)         return from_pointer(d, #d) end

-- Free a packet that is no longer in use.
local function free_internal (p)
--    print ('free_internal', p, S.getpid())
   p.length = 0
   freelist_add(packets_fl, p)
--    print ('done free_internal', p, S.getpid())
end

function free (p)
   stats_count:add(p)
   free_internal(p)
end

-- Return pointer to packet data.
function data (p) return p.data end

-- Return packet data length.
function length (p) return p.length end

function preallocate_step()
--    local pid = S.getpid()
--    print ('preallocate_step', packet_allocation_step, packets_allocated, packets_fl, pid)
   if _G.developer_debug then
      assert(packets_allocated + packet_allocation_step <= max_packets)
   end

--    print ('pre for', pid)
   for i=1, packet_allocation_step do
      free_internal(new_packet(), true)
   end
--    print ('postfor', pid)
   packets_allocated = packets_allocated + packet_allocation_step
   packet_allocation_step = 2 * packet_allocation_step
--    print ('done preallocate_step', packets_fl, pid)
end

ffi.metatype('struct packet', {__index = _M})
