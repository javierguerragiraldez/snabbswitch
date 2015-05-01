
--- ### `Split` app: Split multiple inputs across multiple outputs

-- For each input port, push packets onto outputs. When one output
-- becomes full then continue with the next.

include ('apps.basic.basic')


function push ()
   for _, inport in ipairs(inputi) do
      for _, outport in ipairs(outputi) do
         while not inport:empty() and not outport:full() do
            outport:transmit(inport:receive())
         end
      end
   end
end
