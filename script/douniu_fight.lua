local skynet = require "skynet"
local math = require "math"
local logger = require "logger"
local f_helper = require "fight_helper"

--斗牛战斗信息
local DouNiuEvHandler = {} --事件表
local player_lst = {} --玩家战斗信息
local card_lst = {} --牌堆
local room_status = 0 --0开始阶段 1抢庄阶段 2非庄选倍率 3结算
local status_begin = 0
local room_leader = nil
local room = nil

local function send_user_odds(uid_lst)
	for k, uid in pairs(uid_lst) do
		local p = player_lst[uid]
		if p ~= nil then
			print(">>>>>>>>>>>>>>>>send odds uid ", uid, "odds:", p.odds)
			local player_odds_lst = {}
			table.insert(player_odds_lst,
			{
				uid = uid,
				odds = p.odds,
				hand_card_ready = p.hand_card_ready,
			})
			broadcast_room_player(room.player_lst, "on_odds_change", {room_status = room_status, player_odds_lst = player_odds_lst})
		end
	end
end

local function initRoomPlayer(player)
    --print('initPlayer:')
	local player = {
		uid = player.uid,
		odds = 0,
		icon = player.icon, 
		money = player.money,
		win_money = 0,
		is_leader = false, --庄
		hand_card_lst = {}, --手牌
		niu_num = 0, --牛几
		max_card_num = 0, --最大那张牌
		hand_card_ready = false,
		send_odds = false,
	}

	return player
end

--发牌
local function get_card_from_card_lst(p, num)
	local ret_card_lst = {}
	local cnt = 0
	while cnt < num do
		table.insert(ret_card_lst, card_lst[1])
		table.insert(p.hand_card_lst, card_lst[1])
		table.remove(card_lst, 1)
		cnt = cnt + 1
	end
	--print("card_lst begin:#########")
	--print_t(card_lst)
	--print("card_lst end:#########")
	--推送发牌消息
	if room.player_lst[p.uid] ~= nil and room.player_lst[p.uid].agent ~= nil then
		skynet.call(room.player_lst[p.uid].agent, "lua", "send_pack_cli", "perflop", {card_info = ret_card_lst})
	end

	return true 
end

--更新进度函数
local function update_game_process()
	local leader_uid = 0
	if room_leader ~= nil then
		leader_uid = room_leader.uid
	end

	room.status = room_status

	for k,p in pairs(player_lst) do
		if room.player_lst[p.uid] ~= nil then
			skynet.call(room.player_lst[p.uid].agent, "lua",
			"send_pack_cli", "update_game_process",
			{
				room_id = room.room_id,
				room_odds = room.odds,
				status = room.status,
				leader_uid = leader_uid,
				begin_ts = status_begin,
				proc_interval = enum_game_status_inteval[room.status],
			})
		end
	end
end

local function getPlayer(uid)
	--for player in player_lst do
	--	if uid == player.uid then
	--		return player
	--	end
	--end
	return  player_lst[uid]
end

--返回true是p1赢，否则p2赢
local function compare_hand_card(p1, p2)
	local p1_niu, p1_max_card = parse_card_info(p1.hand_card_lst)
	local p2_niu, p2_max_card = parse_card_info(p2.hand_card_lst)
	
	p1.niu_num = p1_niu
	p1.max_card = p1_max_card
	p2.niu_num = p2_niu
	p2.max_card = p2_max_card

	if p1_niu ~= p2_niu then
		return p1_niu > p2_niu
	end

	return p1_max_card > p2_max_card
end

--斗牛流程控制器
function DouNiuEvHandler:checkStatus()
	--print("on check status")
	if room_status == enum_room_status.ready and os.time() - status_begin > enum_game_status_inteval[room_status] then
		if get_table_nums(player_lst) >= 2 then
			status_begin = os.time()
			room_status = enum_room_status.ask_leader
			update_game_process()
		else
			DouNiuEvHandler:onGameOver()
			return 0
		end
	end

	if room_status == enum_room_status.ask_leader then
		print("on ask leader")

		local notify_user_lst = {}
		local go_next_status = true
		for v,player in pairs(player_lst) do
			if player.odds ~= 0 and player.send_odds == false then
				table.insert(notify_user_lst, player.uid)
				player.send_user_odds = true
			end
			if player.odds == 0 then
				go_next_status = false
			end
		end

		if get_table_nums(notify_user_lst) > 0 then
			send_user_odds(notify_user_lst)
		end

		if go_next_status or os.time() - status_begin > enum_game_status_inteval[room_status] then
			--时间
			status_begin = os.time()

			local max_odds = -1
			local max_rank_num = 0
			local leader = nil

			local notify_user_lst = {}
			for v,player in pairs(player_lst) do
				if player.odds == 0 and player.send_odds == false then
					table.insert(notify_user_lst, player.uid)
				end
			end
			send_user_odds(notify_user_lst)

			--抢庄结果
			for uid,player in pairs(player_lst) do
				print("######get leader, uid:", uid, " odds: ", player.odds)
				if player.odds >= max_odds then
					if player.odds > max_odds then
						max_odds = player.odds 
						leader = player
						max_rank_num = math.random(100)
					else
						local rank_num = math.random(100)
						if rank_num > max_rank_num then
							max_rank_num = rank_num
							leader = player
						end
					end
				end
			end

			leader.is_leader = true
			room_leader = leader
			print("leader:"..leader.uid)
			for v,player in pairs(player_lst) do
				if player.uid ~= leader.uid then
					player.odds = 0
				else
					if player.odds == 0 then
						player.odds = 1
					end
				end
				player.send_odds = false
			end

			--广播leader信息
			room_status = enum_room_status.select_odds
			update_game_process()
		end
	end

	if room_status == enum_room_status.select_odds then
		print("on select_odds")

		local notify_user_lst = {}
		local go_next_status = true
		for v,player in pairs(player_lst) do
			if player.odds == 0 then
				go_next_status = false
			end

			if player.odds ~= 0 and player.send_odds == false then
				table.insert(notify_user_lst, player.uid)
				player.send_odds = true
			end
		end

		if get_table_nums(notify_user_lst) > 0 then
			send_user_odds(notify_user_lst)
		end


		if go_next_status or os.time() - status_begin > enum_game_status_inteval[room_status] then
			local notify_user_lst = {} 
			for uid,player in pairs(player_lst) do
				--没选的全部设为5
				if player.odds == 0 and player.is_leader == false then
					player.odds = 5
					table.insert(notify_user_lst, uid)
				end

				--每人发一张牌
				get_card_from_card_lst(player, 1)
			end

			send_user_odds(notify_user_lst)

			status_begin = os.time()
			room_status = enum_room_status.game_end
			update_game_process()
		end
	end

	if room_status == enum_room_status.game_end then
		--room_status = 0
		--print("on game_end")
		--
		local go_next_status = true
		for v,player in pairs(player_lst) do
			if player.hand_card_ready == false then
				go_next_status = false
				break
			end
		end

		if go_next_status or os.time() - status_begin > enum_game_status_inteval[room_status] then
			for uid,player in pairs(player_lst) do
				if player.uid ~= room_leader.uid then
					local leader = room_leader
					local cp_ret = compare_hand_card(player,leader) 
					local stake = player.odds * leader.odds * room.room_odds
					print("#########uid 1", player.uid, " odds: ", player.odds, " room_odds: ", room.room_odds)
					print("#########uid 2", leader.uid, " odds: ", leader.odds, " room_odds: ", room.room_odds)
					if cp_ret == true then
						stake = stake * get_card_odds(player.niu_num)
						player.win_money = player.win_money + stake
						leader.win_money = leader.win_money - stake
					else
						stake = stake * get_card_odds(leader.niu_num)
						player.win_money = player.win_money - stake
						leader.win_money = leader.win_money + stake
					end
				end
			end

			--广播结果
			local result = {}
			for k, p in pairs(player_lst) do
				local real_res = 0
				--if p.win_money + p.money < 0 then
				--	real_res = -p.moeny
				--end
				real_res = p.win_money
				table.insert(result,
				{
					uid = p.uid,
					result = real_res,
					hand_card_lst = p.hand_card_lst,
					niu_num = p.niu_num,
				}
				)
			end

			broadcast_room_player(room.player_lst, "on_game_result",
			{
				room_id = room.room_id,
				room_odds = room.odds,
				player_ret_lst = result,
			}
			)

			--for k, p in pairs(player_lst) do
			--	print ("on_game_result")
			--	skynet.call(room.player_lst[p.uid].agent, "lua",
			--	"send_pack_cli", "on_game_result",
			--	{
			--		room_id = room.room_id,
			--		room_odds = room.odds,
			--		player_ret_lst = result,
			--	}
			--	)
			--end
			--room_status = enum_room_status.ready
			--update_game_process()
			DouNiuEvHandler:onGameOver()
			return 0
		end
	end

	skynet.timeout(100, DouNiuEvHandler.checkStatus)
	return 1
end

function DouNiuEvHandler:onStart(room_info)
	card_lst = {}
	for i = 1, 52, 1 do
		table.insert(card_lst, i)
	end	

	print(room_info)
	room = room_info
	room_leader = nil
	room_status = enum_room_status.ready
	player_lst = {}

	for k,p in pairs(room.player_lst) do
		player_lst[p.uid] = initRoomPlayer(p)
	end


	--开始事件循环
	room_status = enum_room_status.ready
	status_begin = os.time()
	update_game_process()

	skynet.sleep(5)

	DouNiuEvHandler:onShuffle()
	DouNiuEvHandler.checkStatus()
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
		--local hand_card_num
		--hand_card_num = 0
		--while hand_card_num < 4 do
		--	table.insert(player.hand_card_lst, card_lst[1])
		--	table.remove(card_lst,1)
		--	hand_card_num = hand_card_num + 1
		--end

		--print("card_lst begin:#########")
		--print_t(card_lst)
		--print("card_lst end:#########")
		--推送发牌消息
		--skynet.call(room.player_lst[player.uid].agent, "lua", "send_pack_cli", "perflop", {card_info = player.hand_card_lst})
		
		if player ~= nil then
			get_card_from_card_lst(player, 4)
		end
	end
end

--抢庄
function DouNiuEvHandler:onGetLeader(uid, odds)
    print('DouNiuEvHandler uid: ', uid, 'onGetLeader: ', odds)

	if room_status ~= enum_room_status.ask_leader then
		return -1
	end

	if odds < 0 then
		return -1
	end

	local get_leader_limit = {}
	get_leader_limit[0] = true
	get_leader_limit[1] = true
	get_leader_limit[2] = true
	get_leader_limit[3] = true
	get_leader_limit[4] = true

	local player = getPlayer(uid)
	if player ~= nil then
		if get_leader_limit[odds] == true then
			player.odds = odds
			--send_user_odds({player.uid})
			print('##########DouNiuEvHandler uid: ', uid, 'onGetLeader: ', player.odds)
			return 0
		end
	end
	return -1
end

--非庄选择倍率
function DouNiuEvHandler:onSetOdds(uid, odds)
    print('DouNiuEvHandler onSetOdds:'..odds)

	if room_status ~= enum_room_status.set_odds then
		return -1
	end

	local player = getPlayer(uid)
	if player == nil then
		print('onSetOdds find not player uid:', uid)
		return false
	end

	local set_odds_limit = {
	}
	set_odds_limit[5] = true
	set_odds_limit[10] = true
	set_odds_limit[15] = true
	set_odds_limit[20] = true
	set_odds_limit[25] = true

	if set_odds_limit[odds] ~= true then
		return false
	end

	player.odds = odds
	--send_user_odds({player.uid})
	return true
end

--发最后一张牌
function DouNiuEvHandler:onDropCard()
    print('DouNiuEvHandler onDropCard:')
end

--出牌,检测有没牛
function DouNiuEvHandler:onPackCard(uid, ret_card_lst)
    print('DouNiuEvHandler onPackCard:')
	local sum = 0

	if ret_card_lst == nil then
		return false
	end

	local player = getPlayer(uid)
	if player ~= nil then
		player.hand_card_ready = true
		send_user_odds({uid})
	end

	--local is_niu = false
	--if get_table_nums(ret_card_lst) == 3 then
	--	local player = getPlayer(uid)
	--	if player ~= nil then
	--		for k,card_idx in pairs(ret_card_lst) do
	--			sum = sum + transCard(player.hand_card_lst[card_idx])
	--		end

	--		if sum % 10 == 0 then
	--			is_niu = true
	--			return true
	--		end
	--	end
	--end

	return false
end

--游戏结束
function DouNiuEvHandler:onGameOver()
	print('DouNiuEvHandler:onGameOver')
	skynet.call("DOUNIUSERVER", "lua", "unlock_room", room.room_id)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        --print('douniu fight service !')
        local f = DouNiuEvHandler[cmd]
        if f then
            local ok, result = pcall(f, g_battle,...)
            if not ok then
                error(result)
            end
        else
            assert(false, 'cmd not support '..cmd)
        end
        skynet.ret()
    end)
end)
