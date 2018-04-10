-- ###################################
-- Configuration and UI
-- ###################################

local Config, WifiConfig = dofile("Config.lua")

dofile("TelnetSrv.lua")


-- ###################################
-- System variables
-- ###################################

Tokens = nil
BillToken = nil
Bill = false
OperToken = nil
TokenOK = false
SpindleOn = false
TempOK = false
FeedHold = true
EStop = true
Temps = {}
MQTT = nil
TempTimer = 0
TempTimerSet = 5


Filename = "data.csv"
TempLast = -1

local SpindleState, TokenTimer, TickTimer, LastEStop, LastFeedHold
local CNC_ESTOP, CNC_FEEDHOLD, CNC_SPINDLE, CNC_BILLTOKEN, CNC_OPERTOKEN, CNC_TEMPOKAY, CNC_AUTHED, CNC_BILL, CNC_STATUS, CNC_TEMPREAD, CNC_TRUE, CNC_FALSE = "EStop", "FeedHold", "Spindle", "BillingToken", "OperatorToken", "TempOK", "Authenticated", "Billing", "Status", "Temperature", "true", "false"

-- ###################################
-- MQTT Functions
-- ###################################

local Notify = function(Topic, Message, Retain)
  if type(Retain) ~= "number" then
    Retain = 1
  end
  
  -- pcall() so that if we try to send an MQTT message before we're connected, it doesn't crash
  if MQTT then pcall(function() MQTT:publish("CNC/RFID/" .. Topic, Message, 2, Retain) end) end
end


-- ###################################
-- Token Management
-- ###################################

local AuthorizedOperator = function(Token)
  return Tokens[Token] ~= nil
end

local HandleToken = function(Token)
  -- If we're already "authenticated", then see if we have an operator change
  if TokenOK and ((Token == OperToken) or AuthorizedOperator(Token)) then
  
    -- First, reset the "token timeout" for feed-hold / e-stop
    TokenTimer:stop()
    TokenTimer:start()
    
    -- Now see if the operator has changed
    if Token ~= OperToken then
      OperToken = Token
      Notify(CNC_OPERTOKEN, OperToken)
      
      if not (SpindleOn or Bill) then -- If the operator changes while not billing, change billing operator
        BillToken = Token             -- If you want to swap operators, don't do so with the spindle off!
        Notify(CNC_BILLTOKEN, Token)
      end
      
    end
  
  -- If we're not authenticated (that is, we're locked out), then see if we can unlock the machine for the user
  else
    if AuthorizedOperator(Token) and Tokens[Token] > 0 then
      BillToken = Token
      OperToken = BillToken
      Notify(CNC_AUTHED, CNC_TRUE)
      Notify(CNC_BILLTOKEN, Token)
      Notify(CNC_OPERTOKEN, OperToken)
      TokenTimer:start()
      TokenOK = true
    end
  end
end

-- Deauthenticate users and flag for machine shutdown
function DeAuthenticate()
  BillToken = nil
  OperToken = nil
  Bill = false
  TokenOK = false
  Notify(CNC_AUTHED, CNC_FALSE)
  Notify(CNC_BILLTOKEN, "")
  Notify(CNC_OPERTOKEN, "")
  TokenTimer:stop()
  TokenTimer:start()
end

-- Load token data from CSV file in SPIFFS
function LoadCSVData()
  local CSVFile = file.open(Filename, "r")
  Tokens = {}
  
  if CSVFile == nil then return end
  local Line = CSVFile:readline()
  if Line == nil then
    CSVFile:close()
    return
  end
  
  repeat
    local Split = Line:find(",")
    if Split ~= nil then
      Tokens[Line:sub(1, Split - 1):lower()] = tonumber(Line:sub(Split + 1))
      Line = CSVFile:readline()
    end
  until Line == nil
  
  CSVFile:close()
end

local Reverse = function(In)
  local Out = 0
  local I
  for I = 0, 7 do
    if bit.isset(In, I) then
      Out = bit.set(Out, 7 - I)
    end
  end
  return Out
end

local ValidateToken = function(Input, ValidCallback)
  local Data = {}
  local i = 0
    
  if #Input == 12 then
  
    for i = 1, 9, 2 do
      local n = tonumber(Input:sub(i, i + 1), 16)
      if (n == nil) then
        return
      end
      table.insert(Data,n)
    end
    -- Now checksum
    local Checksum = tonumber(Input:sub(11), 16)
    if (Checksum == nil) then
      return
    end
    Checksum = bit.bxor(Checksum, Data[1], Data[2], Data[3], Data[4], Data[5])
 
    if Checksum == 0 then
      -- Now convert  
      for i = 1, 5 do
        Data[i] = string.format("%02x", Reverse(Data[i]))
      end
  
      ValidCallback(table.concat(Data, ""):lower())
    end
  end
end


-- ###################################
-- File Management
-- ###################################

function UpdateTokens()
  Download(Config.File, Config.File, Config.Server, LoadCSVData)
end

function SaveData()
  local CSVFile = file.open(Filename, "w")
  
  for Token,Time in pairs(Tokens) do
    CSVFile:write(Token .. "," .. tostring(Time) .. "\r\n")
  end
  
  CSVFile:close()
end

function OTAUpdate(Source)
  print("Reboot to bootstrap before performing OTA update - memory not available!")
  return
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


-- ###################################
-- Temperature Checking
-- ###################################

local Convert = function(Input)
  local i = 2
  for i = 2, #Config.Temperature do
    if Config.Temperature[i][1] > Input then
      break
    end
  end
  return (((1000-((Input - Config.Temperature[i-1][1]*1000)/(Config.Temperature[i][1] - Config.Temperature[i-1][1])))*(Config.Temperature[i-1][2] - Config.Temperature[i][2]))/1000)+Config.Temperature[i][2]
end

local CheckTemperature = function()
  table.remove(Temps, Config.TempHist)
  table.insert(Temps, 1, adc.read(0))
  
  local Total = 0
  local Count = 0
  for i = 1, #Temps do
    if Temps[i] > Config.LowFilter and Temps[i] < Config.HighFilter then -- Filter out invalid readings
      Total = Total + Temps[i]
      Count = Count + 1
    end
  end
  if Count > 0 then
    Total = Total / Count
    local T = Total > Config.TempThreshold
    Total = Convert(Total)
    if Total ~= TempLast then
      TempTimer = TempTimer - 1
      if TempTimer <= 0 then
        Notify(CNC_TEMPREAD, tostring(Total))
        TempLast = Total
        TempTimer = TempTimerSet
      end
    else
      TempTimer = TempTimerSet
    end
    
    if TempOK ~= T then
      Notify(CNC_TEMPOKAY, tostring(T))
    end
    TempOK = T
  else
    if TempOK then
      Notify(CNC_TEMPOKAY, CNC_FALSE)
    end
    TempOK = false
  end
end


-- ###################################
-- Event Handlers
-- ###################################

local ReadSerial = function(a)
  a = a:sub(2, 13)
  ValidateToken(a, HandleToken)
end

local Tick = function()
  if gpio.read(5) == 1 then
    SpindleState = false
  else
    SpindleState = true
  end
  
  if SpindleState ~= SpindleOn then
    SpindleOn = SpindleState
    if SpindleOn == true then
      Notify(CNC_SPINDLE, CNC_TRUE)
    else
      Notify(CNC_SPINDLE, CNC_FALSE)
      
      -- If the spindle shuts down while there's no operator token, then mark the machine as deauthenticated
      if BillToken and not OperToken then
        DeAuthenticate()
      end
    end
  end
  
  -- Bill the user if the spindle is running, or -has- been running since they auth'd
  if BillToken and (SpindleOn or Bill) then
    Tokens[BillToken] = Tokens[BillToken] - 1
    if Tokens[BillToken] % 60 == 0 then
      --TODO this should probably be done over HTTP(S) or something instead
      Notify(CNC_BILL, BillToken, 0)
      SaveData()
    end
    Bill = SpindleOn
  else
    Bill = false
  end 
  
  if TokenOK and OperToken and TempOK then
    -- If everything is okay to go, then allow the machine to run  
    FeedHold = false
    EStop = false
  else
    if SpindleOn and TempOK then
      -- If the token was removed, but the spindle is still going (and we aren't overheating)
      FeedHold = true
    else
      -- If the spindle is stopped, OR if the temperature went too high, immediately engage e-stop.
      EStop = true
      Bill = false
    end
  end
  
  if LastFeedHold ~= FeedHold then
  LastFeedHold = FeedHold
    if FeedHold then
      gpio.write(2, 1)
      Notify(CNC_FEEDHOLD, CNC_TRUE)
    else
      gpio.write(2, 0)
      Notify(CNC_FEEDHOLD, CNC_FALSE)
    end
  end
  
  if LastEStop ~= EStop then
    LastEStop = EStop
    if EStop then
      gpio.write(1, 1)
      Notify(CNC_ESTOP, CNC_TRUE)
    else
      gpio.write(1, 0)
      Notify(CNC_ESTOP, CNC_FALSE)
    end
  end
  
  CheckTemperature()
end

-- If no token has been read for 30 seconds, this is called
local TokenTimeout = function()
  -- If the spindle is running, clear the operator token (this will engage feed-hold in Tick())
  if SpindleOn then
    if OperToken then
      OperToken = nil
      Notify(CNC_OPERTOKEN, "")
    end
  elseif BillToken then
    -- If the spindle is not running, lock out the machine
    DeAuthenticate()
  end
end

-- MQTT command recieved
local OnCommand = function(client, topic, message)
  message = string.lower(message)
  if message == "update" then
    UpdateTokens()
  end
  if message == "reboot" then
    node.restart()
  end
end

-- ###################################
-- Startup and Initialization
-- ###################################

uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)

print("")
print("Initializing CNC router access control")
print("")

print("ADC Init...")
if adc.force_init_mode(adc.INIT_ADC) then
  node.restart()
end

print("WiFi Init...")
wifi.setmode(wifi.STATION)
wifi.sta.config(WifiConfig)

local function SyncTime()
  sntp.sync("pool.ntp.org")
end

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function()
  wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
  print("SNTP Sync...")
  SyncTime()
  
  print("Init telnet server...")
  startTelnet()
  
  print("Cache token data...")
  UpdateTokens()
  
  print("Init MQTT...")
  MQTT = mqtt.Client(Config.MQTTId, 120, Config.MQTTUser, Config.MQTTPass, 1)
   
  print("Schedule automatic tasks...")
  cron.schedule("0 * * * *", SaveData)
  cron.schedule("0 */12 * * *", SyncTime)
    
  print("GPIO Init...")
  gpio.mode(1, gpio.OUTPUT)
  gpio.write(1, gpio.HIGH) -- E-Stop
  gpio.mode(2, gpio.OUTPUT)
  gpio.write(2, gpio.HIGH) -- Feed Hold
  gpio.mode(5, gpio.INPUT, gpio.PULLUP) -- Spindle State (High = Off)
  TimeLast = tmr.now()

  print("Timers Init...")
  TokenTimer = tmr.create()
  TokenTimer:register(Config.Timeout, tmr.ALARM_SEMI, TokenTimeout)

  TickTimer = tmr.create()
  TickTimer:register(Config.TickTime, tmr.ALARM_AUTO, Tick)
  TickTimer:start()
  
  print("")
  print("***APPLICATION STARTED***")
  print("")
  MQTT:on("offline", 
    function()
      tmr.create():alarm(10000, tmr.ALARM_SINGLE,
        function()
          MQTT:connect(Config.MQTTServer, Config.MQTTPort, 0)
        end
      )
    end
    )
  MQTT:lwt("CNC/RFID/Status", "Offline")
  MQTT:on("connect", function(c)
    Notify(CNC_STATUS, "Online")
    Notify("IPAddress", wifi.sta.getip())
    MQTT:subscribe("CNC/Command", 1)
    MQTT:on("message", OnCommand)
    print("Controller IP address is ", wifi.sta.getip())
 
    
    uart.on("data", '\003', ReadSerial, 0)
  end
  )
  MQTT:connect(Config.MQTTServer, Config.MQTTPort, 0)
end)

print("Waiting for WiFi start...")