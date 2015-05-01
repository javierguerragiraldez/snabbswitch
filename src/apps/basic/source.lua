--- # `Source` app: generate synthetic packets

local ffi = require('ffi')
local transmit, receive = link.transmit, link.receive

local size = size or 60
local pkt = packet.from_pointer (ffi.new("char[?]", size), size)

include ('apps.basic.basic')


function pull ()
   for _, o in ipairs(outputi) do
      for i = 1, link.nwritable(o) do
         transmit(o, packet.clone(pkt))
      end
   end
end


function stop ()
   packet.free(pkt)
end
