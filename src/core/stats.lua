
local ffi = require('ffi')
local C = ffi.C
local S = require("syscall")
local shm = require('core.shm')

ffi.cdef [[
   uint64_t atomic_add_u64(uint64_t *p, uint64_t x);

   typedef struct {
      uint64_t frees, freebytes, freebits;
   } group;
]]

local stats = {}
stats.__index = stats


function stats:new()
   return setmetatable({
      threadlocal = shm.map('/core.stats', 'group'),
      global = shm.map('//core.stats', 'group'),
   }, self)
end


local function _p(obj, field)
   return ffi.cast('uint64_t *', ffi.cast('unsigned char *', obj)+ffi.offsetof(obj, field))
end


function stats:add(p)
   self.threadlocal.frees = self.threadlocal.frees + 1
   self.threadlocal.freebytes = self.threadlocal.freebytes + p.length
   self.threadlocal.freebits = self.threadlocal.freebits + (math.max(p.length, 46) + 4 + 5) * 8
end


function stats:breathe()
   local newfrees = tonumber(self.threadlocal.frees)
   C.atomic_add_u64(_p(self.global, 'frees'), self.threadlocal.frees)
   C.atomic_add_u64(_p(self.global, 'freebytes'), self.threadlocal.freebytes)
   C.atomic_add_u64(_p(self.global, 'freebits'), self.threadlocal.freebits)
   self.threadlocal.frees = 0
   self.threadlocal.freebytes = 0
   self.threadlocal.freebits = 0
   return newfrees
end


return stats
