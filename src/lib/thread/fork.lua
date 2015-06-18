module(..., package.seeall)

local S = require('syscall')
local stats = require('core.stats')
local lib = require('core.lib')

local function Spawn(modulename)
   local pid = S.fork()
   if pid == 0 then
      require(modulename)
      os.exit()
   end
   return pid
end


function selftest()
   print ('threads', 'frees/sec', 'frees/sec/thread', 'Gbit/sec')
   for n = 0, 20 do
      try_n(n)
   end
end


function try_n(nthreads)
   local stats_count = stats:new()

   stats_count.global.frees = 0
   stats_count.global.freebytes = 0
   stats_count.global.freebits = 0

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
   end
   local total_packets = tonumber(stats_count.global.frees)
   print (nthreads, lib.comma_value(total_packets/10),
      lib.comma_value(total_packets/nthreads/10),
      lib.comma_value(tonumber(stats_count.global.freebits)/10))
end
