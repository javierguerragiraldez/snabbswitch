
local ffi = require('ffi')
local C = ffi.C

ffi.cdef [[
   _Bool cas_int(int *ptr, int expected, int desired);
]]


-- "(int) field pointer", given an object pointer and a field name,
-- returns an int pointer to the field.
local function _fp(obj, field)
   return ffi.cast('int *', ffi.cast('byte_t *', obj)+ffi.offsetof(obj, field))
end


-- BEGIN Stack (LIFO) object
local Stack = {}
Stack.__index = Stack

-- creates an FFI type for a queue with elements of the given type
function Stack:newtype(type)
   local stype = ffi.typeof([[
      struct {
         int head, free;
         struct {
            $ v;
            int next;
         } l[?];
      };
   ]], ffi.typeof(type))
   return ffi.metatype(stype, self)
end

-- creator: creates a stack of the given maximum size
-- initailizes all slots in the freelist
function Stack:__new(size)
   local stk = ffi.new(self, size, -1, 0)
   for i = 0, size-2 do
      stk.l[i].next = i+1
   end
   stk.l[size-1].next = -1;

   return stk
end


-- push an element at the stack head
-- returns the slot number, or nil if there are no free slots
function Stack:push(v)
   local itm = nil
   -- pick a free node
   repeat
      itm = self.free
      if itm == -1 then return nil end
   until C.cas_int(_fp(self, 'free'), itm, self.l[itm].next)

   self.l[itm].v = v

   -- push
   repeat
      self.l[itm].next = self.head
   until C.cas_int(_fp(self, 'head'), self.l[itm].next, itm)
   return itm
end


-- pops an element from the stack head
-- returns the stored element value,
-- or nil if the Stack is empty
function Stack:pop()
   local itm = nil
   -- pop node
   repeat
      itm = self.head
      if itm == -1 then return nil end
   until C.cas_int(_fp(self, 'head'), itm, self.l[itm].next)

   local v = self.l[itm].v
   self.l[itm].v = nil

   -- push in freelist
   repeat
      self.l[itm].next = self.free
   until C.cas_int(_fp(self, 'free'), self.l[itm].next, itm)
   return v
end


-- END Stack object


-- BEGIN Queue object
local Queue = {}
Queue.__index = Queue


function Queue:newtype(type)
   local qtype = ffi.typeof([[
      struct {
         int head, tail, free;
         struct {
            $ v;
            int next;
         } l[?];
      };
   ]], ffi.typeof(type))
   return ffi.metatype(qtype, self)
end


function Queue:__new(size)
   local q = ffi.new(self, size, -1, -1, 0)
   for i = 0, size-2 do
      q.l[i].next = i+1
   end
   q.l[size-1].next = -1;

   return q
end


function Queue:push(v)
   local itm = nil
   -- pick a free node
   repeat
      itm = self.free
      if itm == -1 then return nil end
   until C.cas_int(_fp(self, 'free'), itm, self.l[itm].next)

   self.l[itm].v = v
   self.l[itm].next = -1

   -- push at tail
   local tail = nil
   local done = false
   repeat
      tail = self.tail
      done = C.cas_int(_fp(self.l[tail], 'next'), -1, itm)
      if not done then
         C.cas_int(_fp(self, 'tail'), tail, self.l[tail].next)
      end
   until done
   C.cas_int(_fp(self, 'tail'), tail, itm)

   return itm
end


function Queue:pop()
   local itm = nil
   -- pop head node
   repeat
      itm = self.head
      if self.l[itm].next == -1 then return nil end
   until C.cas_int(_fp(self, 'head'), itm, self.l[itm].next)
   itm = self.l[itm].next

   local v = self.l[itm].v
   self.l[itm].v = nil

   -- push in freelist
   repeat
      self.l[itm].next = self.free
   until C.cas_int(_fp(self, 'free'), self.l[itm].next, itm)

   return v
end

-- END Queue object
-- BEGIN Ring object

local Ring = {}
Ring.__index = Ring


function Ring:newtype(type)
   local rtype = ffi.typeof([[
      struct {
         int head, tail, size;
         $ l [?];
      }
   ]], ffi.typeof(type))
   return ffi.metatype(rtype, self)
end


function Ring:__new(size)
   local r = ffi.new(self, size, 0, 0, size)
   return r
end


function Ring:push(v)
   local tail = nil
   repeat
      tail = self.tail
      if tail == self.head then return nil end
   until C.cas_int(_fp(self, 'tail'), tail, (tail+1)%self.size)
   self.l[tail] = v
   return tail
end


function Ring:pull()
   local head = nil
   repeat
      head = self.head
   until C.cas_int(_fp(self, 'head'), head, (head+1)%self.size)
   if head == self.tail then return nil end
   return self.l[head]
end


-- END Ring object