
for i, l in ipairs(input) do
   input[i] = inter_link(l)
end

-- print ('sink inputs', input, #input)

function pull()
   for _, l in ipairs(input) do
--       print ('sink pull', l, 'empty()', l:empty())
      while not l:empty() do
         l:receive():free()
      end
   end
end
