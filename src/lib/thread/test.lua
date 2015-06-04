module (..., package.seeall)

local Thread = require('lib.thread.init')

function selftest()
   print ('test')
   local spawned = {}
   for i = 1, 3 do
      spawned[i] = Thread('lib.thread.test_code')
   end

   print ('joining')
   for i = 1, #spawned do
      spawned[i]:join()
   end
   print ('manythreads')
end
