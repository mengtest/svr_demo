local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}

local GAME = {}
local player = {}
local fightsvr_inst

function GAME:get()
	print("get", self.what)
	local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
	return { result = r }
end

function GAME:set()
	print("set", self.what, self.value)
	local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function GAME:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function GAME:quit()
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
        local ret = skynet.call("AUTHSERVICE", "lua", "login",self.user_name)
        print('login auth ret ', self.user_name, self.passwd, ret)
        if not ret then
            --net:getConn(player.fd):onLoginFailed("invalid account")
            skynet.call(WATCHDOG, "lua", "close", player.fd)
            return { base_resp = { code = -1, msg = "登陆失败" } }
        end
	player.uid = uid
	player.agent = skynet.self()
	return { base_resp = { code = 0, msg = "登陆" } }
	--net:getConn(player.fd):onLoginSucceed()
end

function GAME:startMatch()
	local ret = skynet.call("MATCHSERVER", "lua", "start", player) 
	if ret == true then
		--net:getConn(player.fd):onMatchStart()
	end
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
			skynet.sleep(500)
		end
	end)

	player.fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
eretnd

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
