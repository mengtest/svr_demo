local skynet = require "skynet"
local math = require "math"
--local CardCfg = require "card_cfg"
--local class = require "class"

--斗牛战斗信息
local DouNiuEvHandler = {} --事件表
local player_lst = {} --玩家战斗信息
local card_lst = {} --牌
local room_status = 0 --0开始阶段 1抢庄阶段 2非庄选倍率 3结算

local function initPlayer()
    print('initPlayer:')
	local player = {
		odds = 0,
		icon = "", 
		money = 0,
		is_win = false,
		is_leader = 0, --庄
		card_lst = {}, --手牌
	}

	return player
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
		local player_card_lst = {}
		for i = 1, i <= 4, 1 do
			table.insert(player_card_lst, card_lst[i])
		end

		--推送发牌消息
		--skynet.call(player.agent, "game", "", player_card_lst) --战斗
		player_card_lst = nil
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
function DouNiuEvHandler:onSetOdds(odds)
    print('DouNiuEvHandler onSetOdds:'..odds)
end

--发最后一张牌
function DouNiuEvHandler:onDropCard()
    print('DouNiuEvHandler onStart:')
end

--出牌,检测有没牛
function DouNiuEvHandler:onPackCard(uid, pack_type, ret_card_lst)
    print('DouNiuEvHandler onPackCard:')
	local sum = 0
	local sanpai = true

	for player in player_lst do
		if player.uid == uid then
			for card_idx in ret_card_lst do
				sum = sum + player.card_lst[card_idx]
			end

			if sum % 10 == 0 then
				sanpai = false
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
        print('fight service !')
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
