
local ffi = require ('ffi')
local C = ffi.C

local statebox = require ('lib.lua.statebox')
require ('lib.cobox.cobox_h')

local cobox = {}
cobox.__index = cobox


function cobox:__new(code)
   local cbx = C.cobox_create(16384)
   assert(cbx.sbx:load([=[
      local ctx_index = (...)
      ffi = require ('ffi')
      local C = ffi.C
      ffi.cdef [[ int cobox_yield (int16_t index, int i); ]]
      function yield(v)
         local v = C.cobox_yield(ctx_index, v)
         if v < 0 then return false, "Error on yield." end
         return v
      end
   ]=],'[cobox header]')):pcall(nil, cbx.ctx)
   assert(cbx.sbx:load(code, '[start]'))

   return cbx
end


-- don't use this while on coroutine, TODO: protect with a flag
function cobox:load(code, name)
   local ok, msg = self.sbx:load(code, name)
   if ok == self.sbx then return self, msg end
   return ok, msg
end


-- don't use this while on coroutine, TODO: protect with a flag
function cobox:pcall(fname, ...)
   return self.sbx:pcall(fname, ...)
end


function cobox:resume(v)
   local v = C.cobox_resume(self.ctx, v or 0)
   if v < 0 then return false, "Error on cobox_resume" end
   return v
end


-- don't use this while on coroutine, TODO: protect with a flag
function cobox:close()
   self.sbx:close()
   C.cobox_destroy(self.ctx);
end

return ffi.metatype('cobox_t', cobox)

