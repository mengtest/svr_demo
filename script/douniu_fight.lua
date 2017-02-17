local skynet = require "skynet"
local math = require "math"
--local CardCfg = require "card_cfg"
--local class = require "class"

--斗牛战斗信息
local DouNiuEvHandler = {} --事件表
local player_lst = {} --玩家战斗信息
local card_lst = {} --牌
local room_status = 0 --0开始阶段 1抢庄阶段 2非庄选倍率 3结算
local status_begin = 0

local function initPlayer()
    print('initPlayer:')
	local player = {
		uid = 0,
		odds = 0,
		icon = "", 
		money = 0,
		is_win = false,
		is_leader = 0, --庄
		hand_card_lst = {}, --手牌
	}

	return player
end

local function getPlayer(uid)
	for player in player_lst do
		if uid == player.uid then
			return player
		end
	end
	return  nil
end

local function broadcast(msg)
	for player in pairs(player_lst) do
		skynet.call(player.agent, "game", "send_package", msg)
	end
end

function DouNiuEvHandler:checkStatus()
	if room_status == 1 then
		if os.time() - status_beigin  > 5 and #player_lst > 2 then
			--时间
			status_begin = os.time()
			room_status = 2
		end
	end

	if room_status == 2 then
		local leader_lst = {}
		for player in pairs(player_lst) do
			player.odds = 1
		end

		if os.time() - status_beigin > 5 then
			--时间
			status_begin = os.time()
		end
		status_begin = os.time()
		room_status = 3
	end

	if room_status == 3 then
		--room_status = 0
		status_begin = os.time()
	end

	skynet.timeout(500, DouNiuEvHandler.checkStatus)
end

function DouNiuEvHandler:onStart()
    print('DouNiuEvHandler onStart:')
	for i = 1, i <= 52, 1 do
		table.insert(card_lst, i)
	end	
end

--洗牌并发4张牌
function DouNiuEvHandler:onShuffle()
    print('DouNiuEvHandler onShuffle:')

	for k,card in ipairs(card_lst) do
		local tmp =  card_lst[k]
		local rank_num = math.random(52)
		card_lst[k] = card_lst[rank_num]
		card_lst[rank_num] = tmp
	end	

	for k,player in ipairs(player_lst) do
		for i = 1, i <= 4, 1 do
			table.insert(player.hand_card_lst, card_lst[i])
		end

		--推送发牌消息
		--skynet.call(player.agent, "game", "", player_card_lst) --战斗
		table.remove(card_lst,0,4)
	end
end

--抢庄
function DouNiuEvHandler:onGetBanker(uid, odds)
    print('DouNiuEvHandler onGetBanker: '..odds)
	local all_ready = true
	for player in ipairs(player_lst) do
		if player.uid == uid then
			player.odds = odds
		end

		if player.odds == 0 then
			all_ready = false
		end
	end

	if all_ready == true then
		room_status = 2
		--推送房间进度信息
		--进入下一个阶段
	end
end

--非庄选择倍率
function DouNiuEvHandler:onSetOdds(uid, odds)
    print('DouNiuEvHandler onSetOdds:'..odds)
	local player = getPlayer(uid)
	player.odds = odds
end

--发最后一张牌
function DouNiuEvHandler:onDropCard()
    print('DouNiuEvHandler onStart:')
end

--出牌,检测有没牛
function DouNiuEvHandler:onPackCard(uid, pack_type, ret_card_lst)
    print('DouNiuEvHandler onPackCard:')
	local sum = 0
	local is_niu = false

	for player in player_lst do
		if player.uid == uid then
			for card_idx in ret_card_lst do
				sum = sum + player.hand_card_lst[card_idx]
			end

			if sum % 10 == 0 then
				is_niu = true
			end
		end
	end

	--推送房间进度信息
	--进入下一个阶段
end

--游戏结束
function DouNiuEvHandler:onGameOver()
	print('DouNiuEvHandler:onGameOver')
	--for uid, player in pairs(g_battle.players_) do
	--	skynet.call(player.agent_, "game", "leaveFight")
	--end
	skynet.exit()
end

local function transBoolNum(boolVar)
    return boolVar and 1 or 0
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        print('douniu fight service !')
        local f = g_battle[cmd]
        if f then
            local ok, result = pcall(f, g_battle, ...)
            if not ok then
                error(result)
            end
        else
            assert(false, 'cmd not support '..cmd)
        end
        skynet.ret()
    end)
end)
