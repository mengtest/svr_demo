package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;proto/?.lua;"

--if _VERSION ~= "Lua 5.3" then
--	error "Use lua 5.3"
--end

local socket = require "clientsocket"
local proto = require "proto"
local sproto = require "sproto"

local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))

local fd = assert(socket.connect("127.0.0.1", 8888))

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
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
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0
local session_map = {}

local function send_request(name, args)
	session = session + 1
	local str = request(name, args, session)
	send_package(fd, str)
	session_map[session] = { name = name, args = args }
	print("Request:", session)
end


------------ register interface begin -------
RpcMgr = {}
local RESPONSE = {}
local REQUEST = {}
RpcMgr.response = RESPONSE
RpcMgr.request = REQUEST
RpcMgr.send_request = send_request
------------ register interface begin -------

function REQUEST:heartbeat(args)
	print("on heartbeat")
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

function RESPONSE:login(args)
	print("on login")
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

------------ s2c ---------------------
local function handle_request (name, args, response)
    print ("--- 【S>>C】, request from server:", name)

    -- if args then
    --     dump (args)
    -- end

    local f = REQUEST[name]
    if f then
        local ret = f(nil, args)
        if ret and response then
            send_message (response (ret))
        end
    else
        print("--- handle_request, not found func:"..name)
    end
end

------------ s2c end ---------------------

------------ c2s begin ---------------------
local function handle_response (id, args)
    local s = assert (session_map[id])
    session_map[id] = nil
    local f = RESPONSE[s.name]

    print ("--- 【S>>C】, response from server:", s.name)
    -- dump (args)

    if f then
        f (s.args, args)
    else
        print("--- handle_response, not found func:"..s.name)
    end
end
------------ c2s end ---------------------


local last = ""

local function print_request(name, args)
	print("REQUEST", name)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function handle_message (t, ...)
    if t == "REQUEST" then
        handle_request (...)
    else
        handle_response (...)
    end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		handle_message(host:dispatch(v))
	end
end

--send_request("handshake")
--send_request("set", { what = "hello", value = "world" })
send_request("login", { base_req = {client_ip="127.0.0.1", os_type=1}, passwd = "456", user_name = "123" })
while true do
	dispatch_package()
	local cmd = socket.readstdin()
	if cmd then
		if cmd == "quit" then
			send_request("quit")
		else
			send_request("get", { what = cmd })
		end
	else
		socket.usleep(100)
	end
end
