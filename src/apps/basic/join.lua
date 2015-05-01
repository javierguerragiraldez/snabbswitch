
--- # `Join` app: Merge multiple inputs onto one output
include ('apps.basic.basic')

function push ()
   local outport = output.out
   for _, inport in ipairs(inputi) do
      while not inport:empty() and not outport:full() do
         outport:transmit(inport:receive())
      end
   end
end
