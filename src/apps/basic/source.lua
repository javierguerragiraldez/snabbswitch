--- # `Source` app: generate synthetic packets

local ffi = require('ffi')

local size = size or 60
local pkt = packet.from_pointer (ffi.new("char[?]", size), size)

include ('apps.basic.basic')


function pull ()
   for _, o in ipairs(outputi) do
      for i = 1, o:nwritable() do
         o:transmit(pkt:clone())
      end
   end
end


function stop ()
   pkt:free(pkt)
end
