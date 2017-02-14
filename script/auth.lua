local skynet = require "skynet"
require "skynet.manager"

local user = 
{
    ["123"] = true,
    ["456"] = true,
}

local login = {}

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, uid) 
		print("test dispatch", session, source, uid)
                if cmd == "login" then
                    if not user[uid] or login[uid] then
                        skynet.ret(skynet.pack(false))
                        return
                    end
                    login[uid] = true
                    print('player login', uid)
                elseif cmd == "logout" then
                    if uid then
                        login[uid] = nil
                        print('player logout', uid)
                    end
                end
                skynet.ret(skynet.pack(true))
	end)
	skynet.register "AUTHSERVICE"
end)
