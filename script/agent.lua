local skynet = require "skynet"
local net = require "net"

local WATCHDOG
local host
local send_request

local CMD = {}
local GAME = {}
local player = {}
local fightsvr_inst

function string.split(str, sep)
	local tbl = {}
	str:gsub('([^'..sep..']+)', function (token) table.insert(tbl, token) end)
	return tbl
end

function table.print(tbl)
	for k, v in pairs(tbl) do
		print(k, v)
	end
end

local function dispatch_game(cmd, ...)
	local tbl = {...}
	local f = GAME[cmd]
	print('dispatch_game', cmd, ...)
	if f then
		local ok, result = pcall(f, GAME, ...) 
		if not ok then
			skynet.error(result)
		end
	else
		assert(false, 'cmd:'..cmd..' not support')
		error('cmd:'..cmd..' not support')
	end
end

function GAME:login(uid)
        local ret = skynet.call("AUTHSERVICE", "lua", "login", uid)
        print('login auth ret ', uid, ret)
        if not ret then
            net:getConn(player.fd):onLoginFailed("invalid account")
            skynet.call(WATCHDOG, "lua", "close", player.fd)
            return
        end
	player.uid = uid
	player.agent = skynet.self()
	net:getConn(player.fd):onLoginSucceed()
end

function GAME:startMatch()
	local ret = skynet.call("MATCHSERVER", "lua", "start", player) 
	if ret == true then
		net:getConn(player.fd):onMatchStart()
	end
end

function GAME:cancelMatch()
	local ret = skynet.call("MATCHSERVER", "lua", "cancel", player) 
        if ret == true then
            net:getConn(player.fd):onMatchCencel()
        end
end

function GAME:placeCard(srcpos, dst_x, dst_y)
	print('placeCard', srcpos, dst_x, dst_y)
	skynet.call(fightsvr_inst, "lua", "placeCard", player, srcpos, dst_x, dst_y)
end

function GAME:selectFight(idx)
        skynet.call(fightsvr_inst, "lua", "selectFight", player, idx)
end

function GAME:heartBeat()
	print('ret heartBeat', player.fd, tostring(os.time()))
	net:getConn(player.fd):onHeartBeat(tostring(os.time()))
end

function GAME:onFightStart(fight)
	fightsvr_inst = fight
end

function GAME:leaveFight()
	print('agent leave fight', player.uid)
	fightsvr_inst = nil
end

function GAME:pickCard(idx)
	print('pick card')
	if fightsvr_inst then
		skynet.call(fightsvr_inst, "lua", "pickCard", player, idx)
	end
end

function GAME:dropCard(idx)
	print('drop card')
	if fightsvr_inst then
		skynet.call(fightsvr_inst, "lua", "dropCard", player, idx)
	end
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function(msg, sz)
		local str = skynet.tostring(msg, sz)
		print('dump:', player.fd, player.uid, str)
		local sp = str:split(' ')
		return table.unpack(sp)
	end,
	dispatch = function (_, _, cmd, ...) 
		dispatch_game(cmd, ...)
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	-- host = sprotoloader.load(1):host "package"
	-- send_request = host:attach(sprotoloader.load(2))
	
	--[[
	skynet.fork(function()
		while true do
			-- send_package(send_request "heartbeat")
			--send_package("heartbeat")
			skynet.sleep(500)
		end
	end)
	--]]

	player.fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
        skynet.call("MATCHSERVER", "lua", "cancel", player)
        skynet.call("AUTHSERVICE", "lua", "logout", player.uid)
	if fightsvr_inst then
		skynet.call(fightsvr_inst, "lua", "logout", player)
	end
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	skynet.dispatch("game", function (_, _, cmd, ...)
		dispatch_game(cmd, ...)
		skynet.ret()
	end)
end)
