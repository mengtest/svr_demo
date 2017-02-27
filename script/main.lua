local skynet = require "skynet"
local redis = require "redis"
local sprotoloader = require "sprotoloader"

local function start_db_service()
	local db_service_cnt = tonumber(skynet.getenv "db_service_cnt")
	for i = 1, db_service_cnt do
		skynet.newservice("db_service", i)
	end
end

skynet.start(function()
	math.randomseed(os.time())
	print("Server start")
	start_db_service()
	skynet.uniqueservice("protoloader")

	--local loginserver = skynet.newservice("logind")
	--local gate = skynet.newservice("gated", loginserver)
	--skynet.call(gate, "lua", "open" , {
	--	port = 8888,
	--	maxclient = 64,
	--	servername = "sample",
	--})

	local watchdog = skynet.newservice("watchdog")
	local debug_console = skynet.newservice("debug_console", 8889)
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = 10000,
		nodelay = true,
	})

	--游戏逻辑相关
	--初始化游戏大厅
	local douniu_room = skynet.newservice("douniu_room")

	skynet.exit()
	print('main exit')
end)
