--- ### `Tee` app: Send inputs to all outputs
include ('apps.basic.basic')


function push()
   for _, inport in ipairs(inputi) do
      while not inport:empty() do
         local pkt = inport:receive()
         local used = false
         for _, outport in ipairs(outputi) do
            if not outport:full() then
               outport:transmit(used and pkt:clone() or pkt)
               used = true
            end
         end
      end
   end
end
