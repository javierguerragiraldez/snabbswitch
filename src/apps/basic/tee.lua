--- ### `Tee` app: Send inputs to all outputs
include ('apps.basic.basic')


function push ()
   local noutputs = #outputi
   if noutputs > 0 then
      local maxoutput = link.max
      for _, o in ipairs(outputi) do
         maxoutput = math.min(maxoutput, o:nwritable())
      end
      for _, i in ipairs(inputi) do
         for _ = 1, math.min(i:nreadable(), maxoutput) do
            local p = i:receive()
            maxoutput = maxoutput - 1
            do local outputi = outputi
               for k = 1, #outputi do
                  outputi[k]:transmit(k == #outputi and p or p:clone())
               end
            end
         end
      end
   end
end
