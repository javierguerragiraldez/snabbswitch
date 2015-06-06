module (..., package.seeall)

local Thread = require('lib.thread.thread')
local stats = require('core.stats')
local lib = require('core.lib')


function selftest()
   print ('threads', 'frees', '/thread')
   for n = 3, 40 do
      try_n(n)
   end
end

function try_n(nthreads)
   local stats_count = stats:new()

   stats_count.global.frees = 0
   stats_count.global.freebytes = 0
   stats_count.global.freebits = 0

   local spawned = {}
   for i = 1, nthreads do
      spawned[i] = Thread('lib.thread.test_code')
   end

   for i = 1, #spawned do
      spawned[i]:join()
   end
   local total_packets = tonumber(stats_count.global.frees)
   print (nthreads, lib.comma_value(total_packets), lib.comma_value(total_packets/nthreads))
end
