module(..., package.seeall)

local S = require('syscall')
local stats = require('core.stats')
local lib = require('core.lib')


local Spawn, Wait = nil, nil
do
   local names = {}
   function Spawn(modulename)
      local pid = S.fork()
      if pid == 0 then
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
   return string.format ("%s: %s frees", name, lib.comma_value(stat.frees))
end


function selftest()
   S.util.rm('/var/run/snabb/interlink')
   local f1 = Spawn('lib.thread.inter_send')
   local f2 = Spawn('lib.thread.inter_sink')

   print (waitandshow())
   print (waitandshow())
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
