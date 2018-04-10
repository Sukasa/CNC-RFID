local Config, WifiConfig = {}, {}

Config.File = "tokens.csv"
Config.Server = "cnc-pi.hq.makerspacenanaimo.org"

Config.TickTime = 1000
Config.TempHist = 32
Config.TempThreshold = 170 -- Set to max range for now (need to get a proper reading)
Config.LowFilter = 0
Config.HighFilter = 255

-- TODO Make this more accurate and take ranges colder than 24*C
Config.Temperature = { {0, 50}, {150, 50}, {160, 41}, {176, 34}, {181, 29}, {190, 26}, {255, 20} }

Config.Timeout = 30000

Config.MQTTId = "CNCRouter"
Config.MQTTServer = "mqtt.hq.makerspacenanaimo.org"
Config.MQTTUser = "CNC_Router"
Config.MQTTPass = "ThisNeedsToBeMoreSecureThanThis"
Config.MQTTPort = 1883

WifiConfig.ssid = "Makerspace MakerLAN"
WifiConfig.pwd = "arduino1"
WifiConfig.auto = true
WifiConfig.save = false

return Config, WifiConfig