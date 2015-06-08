module(..., package.seeall)

local S = require('syscall')
local stats = require('core.stats')
local lib = require('core.lib')

local function Spawn(modulename)
   local pid = S.fork()
   if pid ~= 0 then return pid end
   require(modulename)
end



function selftest()
   local nthreads = 3
   local stats_count = stats:new()

   stats_count.global.frees = 0
   stats_count.global.freebytes = 0
   stats_count.global.freebits = 0

   local spawned = {}
   local invspawn = {}
   for i = 1, nthreads do
      local pid = Spawn('lib.thread.test_code')
      spawned[i] = pid
      invspawn[pid] = i
   end

   while next(invspawn) ~= nil do
      local pid, err = S.waitpid(-1, 0)
      if not pid then
         error(tostring(err))
      end
      print (('pid %d finished'):format(pid))
      invspawn[pid] = nil
   end
   local total_packets = tonumber(stats_count.global.frees)
   print (nthreads, lib.comma_value(total_packets), lib.comma_value(total_packets/nthreads))
end
