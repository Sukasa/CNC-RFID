if startTelnet then
    return
end
    
function startTelnet()
  telnet_srv = net.createServer(net.TCP, 180)
  telnet_srv:listen(23, function(socket)
      local fifo = {}
      local fifo_drained = true
      
      local function sender(c)
          if #fifo > 0 then
            local t = table.remove(fifo, 1)
            c:send(t)
          else
              fifo_drained = true
          end
      end
  
      local function s_output(str)
          table.insert(fifo, str)
          if socket ~= nil and fifo_drained then
              fifo_drained = false
              sender(socket)
          end
      end
  
      node.output(s_output, 0)   -- re-direct output to function s_ouput.
  
      socket:on("receive", function(c, l)
          node.input("") -- Works around a bug where data on the serial pin is STILL INPUT
          tmr.wdclr()
          node.input(l)           -- works like pcall(loadstring(l)) but support multiple separate line
      end)
      socket:on("disconnection", function(c)
          node.output(nil, 0)        -- un-register the redirect output function, output goes to serial
      end)
      socket:on("sent", sender)
  
      print("Connection established\r\n")
      print("> ")
  end
  )

end