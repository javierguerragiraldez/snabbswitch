--- ### `Repeater` app: Send all received packets in a loop

local index = 1
local packets = {}

function push ()
   local i, o = input.input, output.output
   for _ = 1, i:nreadable() do
      local p = i:receive()
      table.insert(self.packets, p)
   end
   local npackets = #packets
   if npackets > 0 then
      for i = 1, o:nwritable() do
         assert(packets[index])
         o:transmit(packets[index]:clone())
         index = (index % npackets) + 1
      end
   end
end


function stop ()
   for i = 1, #packets do
      packets[i]:free()
   end
end

