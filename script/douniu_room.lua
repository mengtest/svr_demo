local skynet = require "skynet"
require "skynet.manager"

local Match = {}
local match_queue = {}


--local class = require "class"
--local CRoom = class() --房间信息

local DOUNIU = {}
local MAX_PLAYER = 6
local max_room_idx = 1
local room_queue = {} --待机房
local running_room_queue = {} --比赛中的房间

function DOUNIU:enterRoom(player)
	print("enterRoom ", player.fd, player.agent)
	local v_room = nil
	for k,v in ipairs(room_queue) do
		print("room "..k.." player size "..#v.player)
		if #v.player < MAX_PLAYER then
			v_room = v
			break
		end
	end

	if v_room == nil then
		max_room_idx = max_room_idx + 1
		local room_info = {
			room_odds = 1, --倍率
			player = {}, --1
			room_id = max_room_idx,
			status = 0 --0待机，1比赛中
		}
		table.insert(room_queue, v_room)
	end

	if v_room ~= nil then
		table.insert(v_room.player, player)
	else
        assert(false, 'get room fail '..table.concat(player,':'))
	end

	--local fightsvr_inst = skynet.newservice("fight")
	--skynet.call(fightsvr_inst, "lua", "start", player)
	--skynet.call(player.agent, "game", "onFightStart", fightsvr_inst)
end

function DOUNIU:leaveRoom(room_id, uid)
	print("remove room begin "..room_id.." player id "..uid)
	for k,v in ipairs(room_queue) do
		if #v.room_id == room_id then
			for idx,p in ipairs(v.player) do
				if p.uid == uid then
					table.remove(v.player, idx)
					return 0
				end
			end
		end
	end

	print("remove fail room_id "..room_id.." player id "..uid)
	return -1
end

function DOUNIU:matchLoop()
	for k,v in ipairs(room_queue) do
		print("room "..k.." player size "..#v.player)
		if #v.player > 2 then
			print("room "..k.." begin match ")
			--大于两个人可以开游戏
			if #v_room.player > 2 then
				DOUNIU:stratGame(v_room)
			end
		end
	end
	skynet.timeout(500, DOUNIU.matchLoop)
end

function DOUNIU:startGame(v_room)
	if v_room.status ~= 1 then
		print("start game ", v_room.room_id)
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
