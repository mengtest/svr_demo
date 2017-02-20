local M = {}

local skynet = require "skynet"
local cur_dbs_id = 1
local db_service_cnt = tonumber(skynet.getenv "db_service_cnt")

function M.call(cmd, ...)
	if cur_dbs_id > db_service_cnt then
		cur_dbs_id = 1
	end
	local service_name = string.format(".db_service_%d", cur_dbs_id)
	local res = {pcall(skynet.call, service_name, "lua", cmd, ...)}
	if not res[1] then
		-- TODO: args to json
		print(string.format("new_dao call fail, cmd=%s, args=%s", cmd, {...}))
		return false, res[2]
	end
	cur_dbs_id = cur_dbs_id + 1
	return true, table.unpack(res, 2)
end

return M
