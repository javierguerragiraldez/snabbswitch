--- ### `Sink` app: Receive and discard packets

include ('apps.basic.basic')


function push ()
   for _, i in ipairs(inputi) do
      for _ = 1, i:nreadable() do
        local p = i:receive()
        p:free()
      end
   end
end
