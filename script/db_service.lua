local skynet = require "skynet"
local mysql = require "mysql"

local dbs_id = ...

local CMD = {}

function CMD.test()
	
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	local service_name = string.format(".db_service_%d", dbs_id)
	skynet.register(service_name)
end)
