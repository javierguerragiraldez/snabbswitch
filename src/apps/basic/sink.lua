--- ### `Sink` app: Receive and discard packets

local transmit, receive = link.transmit, link.receive
local inputi = {}

function relink ()
   inputi = {}
   for _,l in pairs(input) do
      table.insert(inputi, l)
   end
end


function push ()
   for _, i in ipairs(inputi) do
      for _ = 1, link.nreadable(i) do
        local p = receive(i)
        packet.free(p)
      end
   end
end
