
local ffi = require ('ffi')
local C = ffi.C

local statebox = require ('lib.lua.statebox')
require ('lib.cobox.cobox_h')

local cobox = {}
cobox.__index = cobox


function cobox:__new(code)
   local cbx = C.cobox_create(4096)
   assert(cbx.sbx:load [=[
      local ctx_index = (...)
      ffi = require ('ffi')
      local C = ffi.C
      ffi.cdef [[ int cobox_yield (int16_t index, int i); ]]
      function yield(v)
         return C.cobox_yield(ctx_index, v)
      end
   ]=]):pcall(nil, cbx.ctx)
   assert(cbx.sbx:load(code))

   return cbx
end


function cobox:resume(v)
   return C.cobox_resume(self.ctx, v)
end

return ffi.metatype('cobox_t', cobox)

