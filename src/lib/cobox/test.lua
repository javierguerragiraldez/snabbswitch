module(..., package.seeall)
local cobox = require('lib.cobox.cobox')

function selftest()

   print ('main started')
   local co1 = cobox([[
      print ("box #1")
      print ("end")
   ]])
   print ('co1 defined')

   local co2 = cobox([[
      print ('co2 start')
      for i = 1, 3 do
         local yv = yield(i*2)
         print ("co2 yv:", yv)
      end
      print ('co2 fin')
   ]])
   print ('co2 defined')

   local co3 = cobox([[
      print ('co3 start')
      for i = 1, 3 do
         local yv = yield(i+15)
         print ("co3 yv:", yv)
      end
      print ('co3 fin')
   ]])
   print ('co3 and the end of the first part')

   local yi1_v = co1:resume(101)
   print ('yi1_v', yi1_v)
   local yi2_v = co2:resume(121)
   print ('yi2_v', yi2_v)
   local yi3_v = co3:resume(131)
   print ('yi3_v', yi3_v)

   yi2_v = co2:resume(122)
   print ('yi2_v 2', yi2_v)
   yi3_v = co3:resume(132)
   print ('yi3_v 2', yi3_v)

   yi2_v = co2:resume(122)
   print ('yi2_v 2', yi2_v)
   yi3_v = co3:resume(132)
   print ('yi3_v 2', yi3_v)
end
