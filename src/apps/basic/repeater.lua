--- ### `Repeater` app: Send all received packets in a loop

local index = 1
local packets = {}

function push ()
   local inport, outport = input.input, output.output
   while not inport:empty() do
      table.insert(self.packets, inport:receive())
   end
   local npackets = #packets
   if npackets > 0 then
      while not outport:full() do
         assert(packets[index])
         outport:transmit(packets[index]:clone())
         index = (index % npackets) + 1
      end
   end
end


function stop ()
   for _, pkt in ipairs(packets) do
      pkt:free()
   end
end

