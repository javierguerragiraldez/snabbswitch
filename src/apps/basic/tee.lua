--- ### `Tee` app: Send inputs to all outputs
local transmit, receive = link.transmit, link.receive
include ('apps.basic.basic')


function push ()
   local noutputs = #outputi
   if noutputs > 0 then
      local maxoutput = link.max
      for _, o in ipairs(outputi) do
         maxoutput = math.min(maxoutput, link.nwritable(o))
      end
      for _, i in ipairs(inputi) do
         for _ = 1, math.min(link.nreadable(i), maxoutput) do
            local p = receive(i)
            maxoutput = maxoutput - 1
            do local outputi = outputi
               for k = 1, #outputi do
                  transmit(outputi[k], k == #outputi and p or packet.clone(p))
               end
            end
         end
      end
   end
end
