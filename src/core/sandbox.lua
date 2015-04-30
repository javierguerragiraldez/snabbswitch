
local sandbox = {}

-- shallow table copy
local function copy(dst, src)
   for k, v in pairs(src) do
      dst[k] = v
   end
   return dst
end

local environment_mt = {__index = copy({
      packet = require('core.packet'),
      link = require('core.link'),
   }, getfenv())}



-- loads 'dot.named' app
-- returns a 'class', that only serves to call :new(args) on it
function sandbox.load(appname)
   if package.path == '' then
      -- why does main.lua disables package.path?
      package.path = './?.lua;;'
   end
   local path, errmsg = package.searchpath(appname, package.path)
   if not path then return path, errmsg end

   local chunk, errmsg = loadfile(path)
   if not chunk then return chunk, errmsg end

   return {
      _NAME = appname,
      chunk = chunk,
      new = function (self, args)
         args = args or {}
         args.zone = args.zone or appname
         if not getmetatable(args) then setmetatable(args, environment_mt) end

         local ok, errmsg = assert(pcall(setfenv(chunk, args)))
         if not ok then return nil, errmsg end

         return args
      end,
   }
end


return sandbox
