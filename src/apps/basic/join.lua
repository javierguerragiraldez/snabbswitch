
--- # `Join` app: Merge multiple inputs onto one output
include ('apps.basic.basic')

function push ()
   local outport = output.out
   for _, inport in ipairs(inputi) do
      for n = 1,math.min(inport:nreadable(), outport:nwritable()) do
         outport:transmit(inport:receive())
      end
   end
end
