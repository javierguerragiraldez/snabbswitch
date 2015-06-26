
local ffi = require('ffi')
local C = ffi.C
local band = require("bit").band
local shm = require('core.shm')
local packet = require('core.packet')


ffi.cdef [[
   struct ring {
      struct packet *packets[LINK_RING_SIZE];
      int head, mid, tail;
   };

   typedef struct {
      struct ring src, dst;
      double txbytes, rxbytes, txpackets, rxpackets, txdrop;
      int receiving_app;
      bool has_new_data;
   } inter_link_t;
]]

local size = C.LINK_RING_SIZE         -- NB: Huge slow-down if this is not local
local mask = C.LINK_RING_SIZE-1

--- two-parts, three-indices ring structure:
--- the 'front' packets are between head and mid indices
--- the 'back' packets are between mid and tail indices

local ring = {}
ring.__index = ring


function ring:front_empty()
   return self.mid == self.head
end

function ring:back_empty ()
   return self.tail == self.mid
end

function ring:full()
   return band(self.head+1, mask) == self.tail
end


--- adds a packet pointer to the front part
--- returns the given packet pointer,
--- or false if the ring was full (and the pointer wasn't added)
function ring:add(p)
--   assert(p)
   if self:full() then return false end
   self.packets[self.head] = p
   self.head = band(self.head+1, mask)
   return p
end


--- takes a packet pointer from the back part
--- returns false if the back part was empty
function ring:take()
   if self:back_empty() then return false end
   local p = self.packets[self.tail]
   self.tail = band(self.tail+1, mask)
   return p
end

ffi.metatype('struct ring', ring)

------------

--- interprocess link
--- keeps two rings: src and dst, each with front and back parts
--- the front part is between head and mid indices
--- the back part is between mid and tail indices
---
--- src ring:
--- the front part keeps packet pointers to be transmitted.
--- it grows (advancing head index) when the sending process
--- calls l:transmit(p)
--- the back part keeps unused packet pointers.
--- when the src ring is full (head colliding with tail), the back part
--- should be emptied: return the packets to the freelist, advance the tail
--- up to the mid index.
---
--- dst ring:
--- the front part should be kept replenished with empty packet pointers
--- allocated from the freelist by the receiving process.  ideally keeping
--- the ring full.
--- the back part has the payload packet pointers, copied from the src front.
--- when the back is empty (tail == mid), packets pointers should be swapped
--- between rings and the mid indices advanced.
---
--- in effect, full packets move from src.front to dst.back and emtpy packets
--- move from dst.front to src.back



--- packet pointers to be transmitted are added to the
--- src ring's front part.
--- the sr

local inter_link = {}
inter_link.__index = inter_link


function inter_link:__new(name)
   if ffi.istype(self, name) then return name end
   return shm.map(name, self)
end


--- add a packet pointer to src front
--- must be called only from the sending process
--- if src is full, releases packets from back part
--- if it's still full, the packet is dropped (and accounted)
function inter_link:transmit(p)
   local src = self.src
   if src:full() then
      while not src:back_empty() do
         src:take():free()
      end
   end

   if src:add(p) then
      self.txpackets = self.txpackets + 1
      self.txbytes = self.txbytes + p.length
      self.has_new_data = true
   else
      self.txdrop = self.txdrop + 1
      p:free()
   end
end


function inter_link:full()
   return self.src:full() and self.src:back_empty()
end



--- receives a packet pointer
--- must be called only from the receiving process
--- takes packet from dst back part.  it that was empty,
--- advances the mid indices from both rings until either
--- front part is empty, swapping packet pointers between
--- rings as it advances.
function inter_link:receive()
   local dst = self.dst
   if dst:back_empty() then
      while not src:front_empty() and not dst:front_empty() do
        dst.packets[dst.mid], src.packets[src.mid] = src.packets[src.mid], dst.packets[dst.mid]
        src.mid = band(src.mid+1, mask)
        dst.mid = band(dst.mid+1, mask)
      end
   end

   local p = self.dst:take()
   if p then
      self.rxpackets = self.rxpackets + 1
      self.rxbytes = self.rxbytes + p.length
      while not dst:full() do
         dst:add(packet.allocate())
      end
   end
   return p
end

function inter_link:empty()
   return self.dst:back_empty() and (
      self.dst:front_empty() or self.src:front_empty())
end


return ffi.metatype('inter_link_t', inter_link)
