module(...,package.seeall)

local app = require("core.app")
local freelist = require("core.freelist")
local packet = require("core.packet")
local link = require("core.link")
local transmit, receive = link.transmit, link.receive


local ffi = require("ffi")
local C = ffi.C

--- # `Source` app: generate synthetic packets

Source = {}

function Source:new(args)
   print('Source:new', args, args.output, #args.output, args.output[1])
   size = tonumber(args.size) or 60
   local data = ffi.new("char[?]", size)
   print ('Source:new, data', data)
   local p = packet.from_pointer(data, size)
   print ('Source:new, p', p)
   return setmetatable({size=size, packet=p, interOut=args.output}, {__index=Source})
end

function Source:pull ()
--    io.write('+')
   local pkt = self.packet
   for _, o in ipairs(self.interOut) do
      while not o:full() do
--          io.write('=')
         o:transmit(pkt:clone())
      end
   end
end

function Source:stop ()
   packet.free(self.packet)
end

--- # `Join` app: Merge multiple inputs onto one output

Join = {}

function Join:new()
   return setmetatable({}, {__index=Join})
end

function Join:push ()
   for _, inport in ipairs(self.input) do
      for n = 1,math.min(link.nreadable(inport), link.nwritable(self.output.out)) do
         transmit(self.output.out, receive(inport))
      end
   end
end

--- ### `Split` app: Split multiple inputs across multiple outputs

-- For each input port, push packets onto outputs. When one output
-- becomes full then continue with the next.
Split = {}

function Split:new ()
   return setmetatable({}, {__index=Split})
end

function Split:push ()
   for _, i in ipairs(self.input) do
      for _, o in ipairs(self.output) do
         for _ = 1, math.min(link.nreadable(i), link.nwritable(o)) do
            transmit(o, receive(i))
         end
      end
   end
end

--- ### `Sink` app: Receive and discard packets

Sink = {}

function Sink:new (args)
   print ('Sink:new', args, args.input, #args.input, args.input[1])
   return setmetatable({interIn=args.input}, {__index=Sink})
end

function Sink:pull ()
--    io.write('-')
   for _, i in ipairs(self.interIn) do
      while not i:empty() do
--          io.write('*')
         i:receive():free()
--       for _ = 1, link.nreadable(i) do
--         local p = receive(i)
--         packet.free(p)
      end
   end
end

--- ### `Tee` app: Send inputs to all outputs

Tee = {}

function Tee:new ()
   return setmetatable({}, {__index=Tee})
end

function Tee:push ()
   noutputs = #self.output
   if noutputs > 0 then
      local maxoutput = link.max
      for _, o in ipairs(self.output) do
         maxoutput = math.min(maxoutput, link.nwritable(o))
      end
      for _, i in ipairs(self.input) do
         for _ = 1, math.min(link.nreadable(i), maxoutput) do
            local p = receive(i)
            maxoutput = maxoutput - 1
	    do local output = self.output
	       for k = 1, #output do
		  transmit(output[k], k == #output and p or packet.clone(p))
	       end
	    end
         end
      end
   end
end

--- ### `Repeater` app: Send all received packets in a loop

Repeater = {}

function Repeater:new ()
   return setmetatable({index = 1, packets = {}},
                       {__index=Repeater})
end

function Repeater:push ()
   local i, o = self.input.input, self.output.output
   for _ = 1, link.nreadable(i) do
      local p = receive(i)
      table.insert(self.packets, p)
   end
   local npackets = #self.packets
   if npackets > 0 then
      for i = 1, link.nwritable(o) do
         assert(self.packets[self.index])
         transmit(o, packet.clone(self.packets[self.index]))
         self.index = (self.index % npackets) + 1
      end
   end
end

function Repeater:stop ()
   for i = 1, #self.packets do
      packet.free(self.packets[i])
   end
end

