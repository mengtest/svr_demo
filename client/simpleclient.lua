local PATH,IP,PORT= ...

PATH = "."
IP = IP or "192.168.8.59"
PORT = 8888
print(string.format("%s/?.lua",PATH))
package.path = string.format("%s/lualib/?.lua;%s/?.lua;", PATH, PATH)
package.cpath = string.format("%s/luaclib/?.so;", PATH)

local socket = require "simplesocket"
local message = require "simplemessage"

print(string.format("%s/proto/%s", PATH, "proto"))
message.register(string.format("%s/proto/%s", PATH, "dn"))

message.peer(IP, PORT)
message.connect()

local event = {}
local sitIndex = 0
message.bind({}, event)

local mycards
function event:__error(what, err, req, session)
	print("error", what, err)
end

function event:ping()
	-- print("ping")
end

function event:signin(req, resp)
	print("signin", req.userid, resp.ok)
	if resp.ok then
		message.request "ping"	-- should error before login
		message.request "login"
	else
		-- signin failed, signup
		message.request("signup", { userid = "11" })
	end
end

function event:signup(req, resp)
	print("signup", resp.ok)
	if resp.ok then
		message.request("signin", { userid = req.userid })
	else
		error "Can't signup"
	end
end

message.request("login", {base_req={client_ip="192.168.0.1",os_type=1},user_name="123",passwd="456"})
function event:login(req, resp)
	print("login", resp.base_resp.code, resp.base_resp.msg)
end

function event:heartbeat(req, _)
	print("heartbeat:", req)
end

while true do
	message.update()
end
