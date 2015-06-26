
for i, l in ipairs(input) do
   input[i] = inter_link(l)
end


function push()
   for _, l in ipairs(input) do
      while not l:empty() do
         l:receive():free()
      end
   end
end
