--- ### `Repeater` app: Send all received packets in a loop
local transmit, receive = link.transmit, link.receive

local index = 1
local packets = {}

function push ()
   local i, o = input.input, output.output
   for _ = 1, link.nreadable(i) do
      local p = receive(i)
      table.insert(self.packets, p)
   end
   local npackets = #packets
   if npackets > 0 then
      for i = 1, link.nwritable(o) do
         assert(packets[index])
         transmit(o, packet.clone(packets[index]))
         index = (index % npackets) + 1
      end
   end
end


function stop ()
   for i = 1, #packets do
      packet.free(packets[i])
   end
end

