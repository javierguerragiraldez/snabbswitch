--- ### `Sink` app: Receive and discard packets

include ('apps.basic.basic')


function push ()
   for _, inport in ipairs(inputi) do
      while not inport:empty() do
        inport:receive():free()
      end
   end
end
