
--- ### `Split` app: Split multiple inputs across multiple outputs

-- For each input port, push packets onto outputs. When one output
-- becomes full then continue with the next.

local transmit, receive = link.transmit, link.receive
local inputi, outputi = {}, {}

function relink ()
   inputi, outputi = {}, {}
   for _,l in pairs(output) do
      table.insert(outputi, l)
   end
   for _,l in pairs(input) do
      table.insert(inputi, l)
   end
end


function push ()
   for _, i in ipairs(inputi) do
      for _, o in ipairs(outputi) do
         for _ = 1, math.min(link.nreadable(i), link.nwritable(o)) do
            transmit(o, receive(i))
         end
      end
   end
end
