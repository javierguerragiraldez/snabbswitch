
--- # `Join` app: Merge multiple inputs onto one output
local transmit, receive = link.transmit, link.receive
local inputi = {}


function relink ()
   inputi = {}
   for _,l in pairs(input) do
      table.insert(inputi, l)
   end
end


function push ()
   for _, inport in ipairs(inputi) do
      for n = 1,math.min(link.nreadable(inport), link.nwritable(output.out)) do
         transmit(output.out, receive(inport))
      end
   end
end
