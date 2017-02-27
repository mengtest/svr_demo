local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local new_dao = require "new_dao"
local logger = require "logger"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}

local GAME = {}
local player = {}
local room = nil

local function check_login()
	if player.login == nil or player.login == false then
		assert(false, "player_fd:"..player.fd.. " has not login")
	end
end

local function make_resp(errcode, msg)
	return { code = errcode, msg = msg } 
end

local function make_player(player)
	return {name = player.nick_name, icon = player.icon, money = player.money, uid = player.uid }
end

function GAME:enter_room()
	print("enter_room")
	check_login()
	local v_room = skynet.call("DOUNIUSERVER", "lua", "enter_room", player)

	if v_room ~= nil then
		local player_lst = {}
		for _, p in pairs(v_room.player_lst) do
			table.insert(
			player_lst,
			make_player(p)
			)
			--print_t(player_lst)
		end

		room = v_room
		return { base_resp = { code = 0, msg = "进房成功" }, room_id = v_room.room_id, players = player_lst, odds = v_room.room_odds }
	else
		return { base_resp = make_resp(-1, "进入房间失败") }
	end
end

function GAME:set_odds()
	check_login()
	print("set_odds")
	print_t(self)
	if room.fight_ins ~= nil then
		local r = skynet.call(room.fight_ins, "lua", "onSetOdds", player.uid, self.odds)
		return {base_resp=make_resp(0,"")}
	else
		return {base_resp=make_resp(-1,"无效的操作")}
	end
end

function GAME:pack_card()
	check_login()
	print("pack_card")
	print_t(self)
	if room.fight_ins ~= nil then
		local r = skynet.call(room.fight_ins, "lua", "onPackCard", player.uid, self.card_info)
		return {base_resp=make_resp(0,"ok")}
	else
		return {base_resp=make_resp(-1,"无效操作")}
	end
end

function GAME:get_leader()
	check_login()
	if room.fight_ins ~= nil then
		local r = skynet.call(room.fight_ins, "lua", "onGetLeader", player.uid, self.odds)
		return {base_resp=make_resp(0,"ok")}
	else
		return {base_resp=make_resp(-1,"无效的操作")}
	end
	return { base_resp = { code = 0, msg = "ok" } }
end

function GAME:leave_room()
	check_login()
	if room ~= nil then
		local ret = skynet.call("DOUNIUSERVER", "lua", "leave_room", room.room_id, player.uid)
		if ret ~= 0 then
			return { base_resp = make_resp(-1, "离开房间失败") }
		end
	end

	return { base_resp = make_resp(0, "离开房间成功") }
	--skynet.call(WATCHDOG, "lua", "close", client_fd)
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

function GAME:create_room()
	local ret = skynet.call("DOUNIUSERVER", "lua", "create_room", self.odds, player)
end

function GAME:login()
	--if true == check_login() then
	--	--顶下线
	--end

	local ok, res = new_dao.call("get_user_info",
	{user_name = self.user_name, passwd = self.passwd})
	ok = true
	--if not ok then
	--	print("call db_service fail, error: ", res)
	--end

	--local user = res and res[1]
	--if user == nil then
	--	ok = false
	--end

	--print_t(user)
	--print('------db result')
	--print_t(res)
	
	if ok == true then
		player.uid = math.random(50000000)
		--player.uid = user.uid
		player.login = true
		player.nick_name = "test"
		player.money = 200000
		player.icon = ""
		--player.nick_name = user.nick_name
		--player.money = user.money
		--player.icon = user.icon
		print("login success uid:",player.uid)
		--player.agent = skynet.self()
		
		return { base_resp = { code = 0, msg = "登陆成功" }, player_info = make_player(player)}
	else
		player.login = false
		print("login fail");
		return { base_resp = { code = -1, msg = "登陆失败" } }
	end
end

function GAME:startMatch(fight)
	print('startMatch ', fight)
	fightsvr_inst = fight
	--local ret = skynet.call("DOUNIUSERVE", "lua", "start", player) 
		--if ret == true then
	--end
end

function CMD.set_fight(fight_ins)
	if room == nil then
		return false
	end

	room.fight_ins = fight_ins
end

function CMD.send_pack_cli(name, pkg)
	--print("send name ----------")
	--print(name)
	--print_t(pkg)
	send_package(send_request(name, pkg))
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
	GAME:leave_room()
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
