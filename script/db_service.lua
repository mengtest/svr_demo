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

function CMD.get_user_info(args)
	print("get_user_info uid = ", args)
	local res = mysqldb:query("select * from user_info where uid = " .. args)
	return res
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	mysqldb = mysql.connect({
		host = skynet.getenv "mysql_host",
		port = tonumber(skynet.getenv "mysql_port"),
		user = skynet.getenv "mysql_user",
		password = skynet.getenv "mysql_passwd",
		database = skynet.getenv "mysql_dbname",
	})
	
	local service_name = string.format(".db_service_%d", dbs_id)
	skynet.register(service_name)
end)
