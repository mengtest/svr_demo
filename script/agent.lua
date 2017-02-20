local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local new_dao = require "new_dao"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}

local GAME = {}
local player = {}
local fightsvr_inst

function GAME:enter_room()
	print("enter_room")
	local r = skynet.call("DOUNIUSERVER", "lua", "enterRoom", player)

	local player_info = {
		name = "sadf",
		room_type = 1,
		icon = "",
		money = 998,
	}
	
	return { base_resp = { code = 0, msg = "进房成功" }, room_id = 1, player_info = player_info }
end

function GAME:onPackCard()
	print("set", self.what, self.value)
	local r = skynet.call("DOUNIUSERVER", "lua", "onPackCard", self.what, self.value)
end

function GAME:get_leader()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function GAME:leave_room()
	skynet.call("DOUNIUSERVER", "lua", "leaveRoom", client_fd)
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

local function request(name, args, response)
	local f = assert(GAME[name])
	local r = f(args)
	if response then
		return response(r)
	end
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(player.fd, package)
end

function GAME:login()
--        local ret = skynet.call("AUTHSERVICE", "lua", "login",self.user_name)
--        print('login auth ret ', self.user_name, self.passwd, ret)
--        if not ret then
--            skynet.call(WATCHDOG, "lua", "close", player.fd)
--            return { base_resp = { code = -1, msg = "登陆失败" } }
--        end
--	player.uid = uid
--	player.agent = skynet.self()
	
	-- TODO: 测试操作
	local ok, res = new_dao.call("get_user_info", 1000)
	if not ok then
		print("call db_service fail, error: ", res)
	end

	local function dump(t)
		for k, v in pairs(t) do
			print('***', k, v)
		end
	end
	
	print('------db result')
	for k, v in ipairs(res) do
		print(k, dump(v))
	end
	
	return { base_resp = { code = 0, msg = "登陆成功" } }
end

function GAME:startMatch(fight)
	print('startMatch ', fight)
	fightsvr_inst = fight
	--local ret = skynet.call("DOUNIUSERVE", "lua", "start", player) 
	--if ret == true then
	--end
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (_, _, type, ...)
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...)
			if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	send_request = host:attach(sprotoloader.load(2))
	skynet.fork(function()
		while true do
			send_package(send_request "heartbeat")
			--print("send heart")
			skynet.sleep(500)
		end
	end)

	player.fd = fd
	player.agent = skynet.self()
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
