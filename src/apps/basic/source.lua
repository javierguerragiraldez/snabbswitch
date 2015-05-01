--- # `Source` app: generate synthetic packets

local ffi = require('ffi')

local size = size or 60
local pkt = packet.from_pointer (ffi.new("char[?]", size), size)

include ('apps.basic.basic')


function pull ()
   for _, outport in ipairs(outputi) do
      while not outport:full() do
         outport:transmit(pkt:clone())
      end
   end
end


function stop ()
   pkt:free(pkt)
end
