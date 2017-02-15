local sprotoparser = require "sprotoparser"

local proto = {}

local function get_file_text(filename)
	local file = io.open(filename, "r")
	local text = file:read("*a")
	file:close()
	return text
end

local c2s_text = get_file_text("c2s.sproto")
proto.c2s = sprotoparser.parse(c2s_text)

local s2c_text = get_file_text("s2c.sproto")
proto.s2c = sprotoparser.parse(s2c_text) 

return proto
