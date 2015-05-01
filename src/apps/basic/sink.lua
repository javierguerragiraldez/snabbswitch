--- ### `Sink` app: Receive and discard packets

local transmit, receive = link.transmit, link.receive
include ('apps.basic.basic')


function push ()
   for _, i in ipairs(inputi) do
      for _ = 1, link.nreadable(i) do
        local p = receive(i)
        packet.free(p)
      end
   end
end
