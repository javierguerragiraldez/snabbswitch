
--- ### `Split` app: Split multiple inputs across multiple outputs

-- For each input port, push packets onto outputs. When one output
-- becomes full then continue with the next.

local transmit, receive = link.transmit, link.receive
include ('apps.basic.basic')


function push ()
   for _, i in ipairs(inputi) do
      for _, o in ipairs(outputi) do
         for _ = 1, math.min(link.nreadable(i), link.nwritable(o)) do
            transmit(o, receive(i))
         end
      end
   end
end
