if file.exists("TelnetSrv.lua") then
  dofile("TelnetSrv.lua")
  startTelnet()
end

Config, WifiConfig = dofile("Config.lua")
wifi.sta.config(WifiConfig)
  
Start = function() 
    local f = file.open(".flag", "w")
    f:close()
    node.restart()
end

function OTAUpdate(Source, Dest, Reboot)
  Dest = Dest or "app.lua"
  if Reboot == nil then Reboot = true end
  
  local SourceFile = string.find(Source, "://")
  local Split = string.find(Source, "/", SourceFile + 3)
  local Host = string.sub(Source, SourceFile + 3, Split - 1)
  SourceFile = string.sub(Source, Split + 1)
  
  Download(SourceFile, Dest, Host,
    function()
      print("Downloaded "..Dest..".")
      if Dest ~= "app.lua" or not Reboot then return end
      print("Rebooting to application")
      local f = file.open(".flag", "w")
      if f then
        f:close()
      end
      node.restart()
    end
  )
end

function Download(Filename, ToFile, Host, OnComplete, OnFail) 
  local Buffer, DLFile, conn, ParsingHeaders = nil, nil, net.createConnection(net.TCP, 0), true

  print("Doing download: ", Filename, ToFile, Host)
  
  local function StripHeaders(Data)
    Buffer = Buffer .. Data
    local T = Buffer:find("\r\n")
    while T ~= nil do
      Buffer = Buffer:sub(T + 2)
      T = Buffer:find("\r\n") 
      if T == 1 then
        ParsingHeaders = false
        DLFile:write(Buffer:sub(3))
        Buffer = nil
        return
      end
    end
    return nil
  end
  
  conn:on("receive", function(socket, Data)
    print("RX...")
    if ParsingHeaders then
      StripHeaders(Data)
    else
      DLFile:write(Data)
    end
  end)
  
  conn:on("connection", function(socket, data) 
    print("Connected...")
    ParsingHeaders = true
    Buffer = ""
    DLFile = file.open(ToFile, "w")
    
    conn:send("GET /".. Filename .. " HTTP/1.1\r\nhost: " .. Host .. "\r\nconnection: close\r\nUser-Agent: NodeMCU Lua (CNC Router)\r\n\r\n")
  end)
  
  conn:on("disconnection", function(socket, data)
    print("Disconnected.")
    if DLFile ~= nil then
      DLFile:close()
      DLFile = nil
      if OnComplete then
        OnComplete()
      end
    elseif OnFail then
      OnFail()
    end
    conn = nil
    Buffer = nil
  end)
  
  conn:connect(80, Host)
  
end