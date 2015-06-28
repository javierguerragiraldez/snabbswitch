
local size = size or 60
local pkt = packet.from_pointer (ffi.new("char[?]", size), size)

for i, l in ipairs(output) do
   output[i] = inter_link(l)
end

function pull()
   for _, l in ipairs(output) do
--       print ('source pull: link', l, 'full:', l:full())
      while not l:full() do
         l:transmit(pkt:clone())
      end
   end
end


function stop()
   pkt:free()
end
