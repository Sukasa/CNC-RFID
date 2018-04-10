uart.setup(0,9600,8,0,1 )
print("Performing init...")
local a,e = node.bootreason()
print("Boot reasons: ", a, e)
if (e~=4 and e~=7 and e~=3) or file.exists(".flag") then

  print("Attempt normal boot")
  if file.exists(".flag") then file.remove(".flag") end
  dofile("app.lua")
  print("Normal Boot Complete")
elseif file.exists("Bootstrap.lua") then
  print("Attempt Bootstrap")
  dofile("Bootstrap.lua")
end