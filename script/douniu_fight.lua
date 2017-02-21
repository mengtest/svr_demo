local skynet = require "skynet"
local math = require "math"
--local CardCfg = require "card_cfg"
--local class = require "class"

--斗牛战斗信息
local DouNiuEvHandler = {} --事件表
local player_lst = {} --玩家战斗信息
local card_lst = {} --牌堆
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

local function transCard(card_num)
	if card_num % 13 + 1 >= 10 then
		return 10
	end

	return card_num % 13 + 1 
end

local function broadcast(name,pkg)
	for player in pairs(player_lst) do
		skynet.call(player.agent, "lua", "send_pack_cli", name, pkg)
	end
end

--斗牛流程控制器
function DouNiuEvHandler:checkStatus()
	if room_status == 1 then
		if os.time() - status_beigin  > 5 and #player_lst > 2 then
			--时间
			status_begin = os.time()

			local max_odds = 0
			local max_rank_num = 0
			local leader = nil
			--抢庄结果
			for _,player in pairs(player_lst) do
				if player.odds >= max_odds then
					if player.odds > max_odds then
						max_odds = player.odds 
						leader = player
						max_rank_num = meth.rank(100)
					else
						local rank_num = meth.rank(100)
						if rank_num > max_rank_num then
							max_rank_num = rank_num
							leader = player
						end
					end
				end
			end

			leader.is_leader = true
			--广播leader信息
			room_status = 2
		end
	end

	if room_status == 2 then
		local leader_lst = {}
		for player in pairs(player_lst) do
			player.odds = 0
		end

		if os.time() - status_beigin > 5 then
			--时间
			status_begin = os.time()
			for _,player in pairs(player_lst) do
				--没选的全部设为5
				if player.odds == 0 then
					player.odds = 5
				end
			end
			status_begin = os.time()
			room_status = 3
		end
	end

	if room_status == 3 then
		--room_status = 0
		status_begin = os.time()
		for _,player in ipairs(player_lst) do
			--强制亮牌,计算结果
		end
	end

	skynet.timeout(500, DouNiuEvHandler.checkStatus)
end

function DouNiuEvHandler:onStart(players)
    print('DouNiuEvHandler onStart:')
	for i = 1, i <= 52, 1 do
		table.insert(card_lst, i)
	end	

	DouNiuEvHandler:onShuffle()
end

--洗牌并发4张牌
function DouNiuEvHandler:onShuffle()
    print('DouNiuEvHandler onShuffle:')

	for k,card in pairs(card_lst) do
		local tmp =  card_lst[k]
		local rank_num = math.random(52)
		card_lst[k] = card_lst[rank_num]
		card_lst[rank_num] = tmp
	end	

	for k,player in pairs(player_lst) do
		for i = 1, i <= 4, 1 do
			table.insert(player.hand_card_lst, card_lst[i])
		end

		--推送发牌消息
		skynet.call(player.agent, "lua", "send_pack_cli", "perflop", player_card_lst) --战斗
		table.remove(card_lst,1,4)
	end
end

--抢庄
function DouNiuEvHandler:onGetBanker(uid, odds)
    print('DouNiuEvHandler onGetBanker: '..odds)

	local player = getPlayer(uid)
	if player ~= nil then
		player.odds = odds
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
    rint('DouNiuEvHandler onPackCard:')
	local sum = 0
	local is_niu = false

	local player = getPlayer(uid)
	for card_idx in ret_card_lst do
		sum = sum + transCard(player.hand_card_lst[card_idx])
	end

	if sum % 10 == 0 then
		is_niu = true
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
        local f = DouNiuEvHandler[cmd]
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
