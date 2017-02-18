local skynet = require "skynet"
require "skynet.manager"
local mysql = require "mysql"

local dbs_id = ...
local mysqldb

local CMD = {}

function CMD.test(args)
	print("db_service args = ", args)
	local res = mysqldb:query("select 12345")
	return res
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	mysqldb = mysql.connect({
		host = "127.0.0.1",
		port = 3306,
		user = "root",
		password = "root",
	})
	
	local service_name = string.format(".db_service_%d", dbs_id)
	skynet.register(service_name)
end)
