-- 'config' is a data structure that describes an app network.

module(..., package.seeall)

local lib = require("core.lib")
local sandbox_loader = require('core.sandbox_loader')

-- API: Create a new configuration.
-- Initially there are no apps or links.
function new ()
   return {
      procs = {},        -- list of {mask}
      apps = {},         -- list of {name, class, args}
      links = {}         -- table with keys like "a.out -> b.in"
   }
end

-- API: Add a process to the configuration.
--
-- config.proc(c, name, {specifications})
-- the specifications should allow the integrator
-- to restrict on which CPU(s) will this process
-- execute.
function proc(config, name, specs)
   assert(type(name) == "string", "name must be a string")
   config.procs[name] = { mask=specs.mask }
end

-- API: Add an app to the configuration.
--
-- config.app(c, name, class, arg [, proc]):
--   c is a config object.
--   name is the name of this app in the network (a string).
--   class is the Lua object with a class:new(arg) method to create the app.
--   arg is the app's configuration (to be passed to new()).
--   proc is the process name to run this app
--
-- Example: config.app(c, "nic", Intel82599, {pciaddr = "0000:00:01.00"})
function app (config, name, class, arg, proc)
--    arg = arg or "nil"
   assert(type(name) == "string", "name must be a string")
   if type(class) == 'string' then
      class = sandbox_loader(class)
   end
   assert(type(class) == "table", "class must be a table")
   assert(type(proc) == 'string', "proc must be a string")
   config.apps[name] = { class = class, arg = arg, proc=proc}
end

-- API: Add a link to the configuration.
--
-- Example: config.link(c, "nic.tx -> vm.rx")
function link (config, spec)
   config.links[canonical_link(spec)] = true
end

-- Given "a.out -> b.in" return "a", "out", "b", "in".
function parse_link (spec)
   local fa, fl, ta, tl = spec:gmatch(link_syntax)()
   if fa and fl and ta and tl then
      return fa, fl, ta, tl
   else
      error("link parse error: " .. spec)
   end
end

link_syntax = [[ *([%w_]+)%.([%w_]+) *-> *([%w_]+)%.([%w_]+) *]]

function format_link (fa, fl, ta, tl)
   return ("%s.%s -> %s.%s"):format(fa, fl, ta, tl)
end

function canonical_link (spec)
   return format_link(parse_link(spec))
end

function short_linkname(spec)
   return ('%s.%s-%s.%s'):format(parse_link(spec))
end

-- Return a Lua object for the arg to an app. Arg may be a table or a
-- string encoded Lua object.
-- Example:
--   parse_app_arg('{ timeout= 5*10 }') => { timeout = 50 }
--   parse_app_arg(<table>) => <table> (NOOP)
function parse_app_arg (arg)
   if     type(arg) == 'string' then return lib.load_string(arg)
   elseif type(arg) == 'table'  then return arg
   else   error("<arg> is not a string or table.") end
end

function graphviz (c)
   local viz = 'digraph config {\n'
   local function trim (name) return name:sub(0, 12) end
   for linkspec,_ in pairs(c.links) do
      local fa, fl, ta, tl = config.parse_link(linkspec)
      viz = viz..'  '..trim(fa).." -> "..trim(ta)..' [taillabel="'..fl..'" headlabel="'..tl..'"]\n'
   end
   viz = viz..'}\n'
   return viz
end
