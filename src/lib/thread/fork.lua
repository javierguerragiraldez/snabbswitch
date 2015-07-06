module(..., package.seeall)

local S = require('syscall')
local stats = require('core.stats')
local lib = require('core.lib')
local inter_link = require('lib.thread.inter_link')


local function each_module(fname)
   print ('each_module', fname)
   for modname, module in pairs(package.loaded) do
      if type(module) == 'table' and rawget(module, fname) then
         print ('calling', modname, fname)
         module[fname]()
      end
   end
end

local Spawn, Wait = nil, nil
do
   local names = {}
   function Spawn(modulename)
      each_module('prefork')
      local pid = S.fork()
      if pid == 0 then
         each_module('postfork')
         require(modulename)
         os.exit()
      end
      names[pid] = modulename
      return pid
   end
   function Wait()
      if next(names) == nil then return nil end
      local pid = assert(S.waitpid(-1, 0))
      local name = names[pid]
      names[pid] = nil
      return pid, name
   end
end


local function waitandshow()
   local pid, name = Wait()
   local stat = stats(pid)
   return string.format ("%s: %s frees, %s bytes", name,
      lib.comma_value(stat.frees), lib.comma_value(stat.freebytes))
end


function selftest()
--    for _ = 1, 10 do
--       memory.allocate_next_chunk ()
--    end
   local f1 = Spawn('lib.thread.inter_send')
   local f2 = Spawn('lib.thread.inter_sink')

   print (waitandshow())
   print (waitandshow())
   inter_link('/interlink'):report('interlink')
end


function selftest_perf()
   print ('threads', 'frees/sec', 'frees/sec/thread', 'Gbit/sec')
   for n = 0, 20 do
      try_n(n)
   end
end


function try_n(nthreads)
   local stats_count = stats()

   local spawned = {}
   local invspawn = {}
   for i = 1, nthreads do
--       local pid = Spawn('lib.thread.test_code')
      local pid = Spawn('lib.thread.test_tunnel')
      spawned[i] = pid
      invspawn[pid] = i
   end

   while next(invspawn) ~= nil do
      local pid, err = S.waitpid(-1, 0)
      if not pid then
         error(tostring(err))
      end
--       print (('pid %d finished'):format(pid))
      invspawn[pid] = nil
      stats_count:accumulate(stats(pid))
   end
   local total_packets = tonumber(stats_count.frees)
   print (nthreads, lib.comma_value(total_packets/10),
      lib.comma_value(total_packets/nthreads/10),
      lib.comma_value(tonumber(stats_count.freebits)/10))
end
