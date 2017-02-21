local skynet = require "skynet"
require "skynet.manager"
local logger = require "logger"

local Match = {}
local match_queue = {}


--local class = require "class"
--local CRoom = class() --房间信息

local DOUNIU = {}
local MAX_PLAYER = 6
local max_room_idx = 1
local room_queue = {} --待机房
local running_room_queue = {} --比赛中的房间

local function make_room_info(room)
	local players = {}
	for uid,player in pairs(room.player_lst) do
		table.insert(players, 
		{
			icon = player.icon,
			money = player.money,
			name = player.nick_name,
			odds = 0,
			is_leader = false,
		}
		)
	end

	print("update_room_info room_id:"..room.room_id)
	return 
	{
		room_id = room.room_id,
		room_odds = room.room_odds,
		status = room.status,
		players = players,
	}
end

function DOUNIU:enter_room(player)
	local v_room = nil
	for k,v in pairs(room_queue) do
		print("room "..k.." player size "..#v.player_lst)
		if #v.player_lst < MAX_PLAYER then
			v_room = v
			break
		end
	end

	if v_room == nil then
		max_room_idx = max_room_idx + 1
		local room_info = {
			room_odds = 1, --倍率
			player_lst = {}, --1
			room_id = max_room_idx,
			status = 0 --0待机，1比赛中
		}
		--table.insert(room_queue, room_info)
		room_queue[room_info.room_id] = room_info
		v_room = room_info
	end

	if v_room ~= nil then
		print_t(player)
		v_room.player_lst[player.uid] = player
		--table.insert(v_room.player_lst, tonumber(player.uid), player)
	else
        assert(false, 'enter room fail ')
		return nil
	end

	for uid, room_player in pairs(v_room.player_lst) do
		print("update room info")
		--if uid ~= player.uid then
			--skynet.call(room_player.agent, "lua", "update_room_info", v_room)
		--end
		skynet.call(room_player.agent, "lua",
		"send_pack_cli", "update_room_info",
		make_room_info(v_room))
	end
	print("enterRoom success uid:", player.uid, " room_id:", v_room.room_id)
	--local fightsvr_inst = skynet.newservice("fight")
	--skynet.call(fightsvr_inst, "lua", "start", player)
	--skynet.call(player.agent, "game", "onFightStart", fightsvr_inst)
	return v_room
end

function DOUNIU:leave_room(room_id, uid)
	print("remove room begin "..room_id.." player id "..uid)
	for k,v in pairs(room_queue) do
		if v.room_id == room_id then
			v.player_lst[uid] = nil
			return 0
		end
	end

	print("remove fail room_id "..room_id.." player id "..uid)
	return -1
end

function DOUNIU:matchLoop()
	for k,v in ipairs(room_queue) do
		print("room "..k.." player size "..#v.player_lst)
		if #v.player_lst > 2 then
			print("room "..k.." begin match ")
			--大于两个人可以开游戏
			if #v_room.player_lst > 2 then
				DOUNIU:stratGame(v_room)
			end
		end
	end
	skynet.timeout(500, DOUNIU.matchLoop)
end

function DOUNIU:startGame(v_room)
	if v_room.status ~= 1 then
		print("start game, room_id: ", v_room.room_id)
		--local fightsvr_inst = skynet.newservice("douniu_fight")
		--for player in ipairs(v_room.player) do
		--	skynet.call(player.agent, "game", "onFightStart", fightsvr_inst)
		--end
	end
	--local fightsvr_inst = skynet.newservice("fight")
	--skynet.call(fightsvr_inst, "lua", "start", player_1, player_2)
	--skynet.call(player_1.agent, "game", "onFightStart", fightsvr_inst)
	--skynet.call(player_2.agent, "game", "onFightStart", fightsvr_inst)
end

function DOUNIU:start(player)
    table.insert(match_queue, player)
    print('[DOUNIU] start', player.uid, player)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		print('douniu server !', session, source, cmd)
		local f = DOUNIU[cmd]
		skynet.ret(skynet.pack(f(DOUNIU, ...)))
	end)

	skynet.timeout(500, DOUNIU.matchLoop)
	
	skynet.register "DOUNIUSERVER"
end)
