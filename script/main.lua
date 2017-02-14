local skynet = require "skynet"
local redis = require "redis"

local conf = 
{
	host = "127.0.0.1",
	port = 6379,
	db = 0
}

skynet.start(function()
	--local db = redis.connect(conf)
	--db:set('A', 555)
	--print(db:get('A'))
	math.randomseed(os.time())
	print("Server start")
	local match = skynet.newservice("match")
	local auth = skynet.newservice("auth")
	--local dao = skynet.newservice("dao")
	local watchdog = skynet.newservice("watchdog")
	local debug_console = skynet.newservice("debug_console", 8889)
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.exit()
	print('main exit')
end)
