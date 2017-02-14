local skynet = require "skynet"

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		print("test dispatch", session, source, cmd, subcmd)
	end)
end)
