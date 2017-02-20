--luasocket
local lsocket = require "socket"

local socket = {}
local fd
local message

socket.error = setmetatable({}, { __tostring = function() return "[socket error]" end } )

function socket.connect(addr, port)
	assert(fd == nil)
	fd = lsocket.connect(addr, port)
	if fd == nil then
		error(socket.error)
	end

	lsocket.select({fd},nil,nil)
	local ok, errmsg = fd:getstats()
	if not ok then
		error(socket.error)
	end

	message = ""
end

function socket.isconnect(ti)
	local rd, wt = lsocket.select(nil, { fd }, ti)
	return next(wt) ~= nil
end

function socket.close()
	fd:close()
	fd = nil
	message = nil
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = fd:receive(1)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end


function socket.read(ti)
	while true do
		local v
		v, message = recv_package(message)
		if not v then
			break
		end

		return v
		--local ok, msg, n = pcall(string.unpack, ">s2", message)
		--if not ok then
		--	local rd = lsocket.select { fd , ti }
		--	if next(rd) == nil then
		--		return nil
		--	end
		--	local p = fd:receive(1)
		--	if not p then
		--		error(socket.error)
		--	end
		--	message = message .. p
		--else
		--	message = message:sub(n)
		--	return msg
		--end
	end
end

function socket.write(msg)
	local pack = string.pack(">s2", msg)
	repeat
		local bytes = fd:send(pack)
		if not bytes then
			error(socket.error)
		end
		pack = pack:sub(bytes+1)
	until pack == ""
end

return socket
