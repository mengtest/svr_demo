local skynet = require "skynet"
--local net = require "net"
--local net = require "net"
require "skynet.manager"

local Match = {}
local match_queue = { }

function Match:startGame(player_1, player_2)
	print("start game ", player_1.fd, player_1.agent, player_2.fd, player_2.agent)
	local fightsvr_inst = skynet.newservice("fight")
	skynet.call(fightsvr_inst, "lua", "start", player_1, player_2)
	skynet.call(player_1.agent, "game", "onFightStart", fightsvr_inst)
	skynet.call(player_2.agent, "game", "onFightStart", fightsvr_inst)
end

function Match:matchLoop()
	while #match_queue >= 2 do
		Match:startGame(match_queue[1], match_queue[2])
		table.remove(match_queue, 1)
		table.remove(match_queue, 1)
	end
	skynet.timeout(500, Match.matchLoop)
end

function Match:cancel(player)
    local idx = -1
    for i, v in ipairs(match_queue) do
        if v.uid == player.uid then
            idx = i
            break
        end
    end

    if idx ~= -1 then
        table.remove(match_queue, idx)
    	print('[match] cancel', player.uid, player, idx)
    end
end

function Match:start(player)
    table.insert(match_queue, player)
    print('[match] start', player.uid, player)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		print('match server !', session, source, cmd)
                local f = Match[cmd]
		skynet.ret(skynet.pack(f(Match, ...)))
	end)

	skynet.timeout(500, Match.matchLoop)
	
	skynet.register "MATCHSERVER"
end)
