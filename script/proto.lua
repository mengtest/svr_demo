local sprotoparser = require "sprotoparser"

local proto = {}

proto.c2s = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

.BaseReq {
	client_ip 0 : string
	os_type 1 : integer
}

.BaseResp {
	code 0 : integer #错误码
	msg 1 : string  #错误信息
}

.PlayerInfo {
	name 0 : string
	icon 1 : string #头像url
	money 2 : integer 
}

enter_room 1 {
	request {
		base_req 0 : BaseReq
		room_type 1 : integer #倍率房
		room_id 2 : integer #房间Id,可选字段
	}
	response {
		base_resp 0 : BaseResp
		room_id 1 : integer 
		players 2 : *PlayerInfo #玩家信息
		odds 3 : integer #赔率信息
	}
}

drop_card 2 {
	request {
		base_req 0 : BaseReq
		card_info 1 : *integer
	}
	response {
		base_resp 0 : BaseResp
	}
}

get_leader 3 {
	request {
		base_req 0 : BaseReq
		odds 1 : integer #赔率
	}
	response {
		base_resp 0 : BaseResp
	}
}

leave_room 4 {}

login 5 {
	request {
		base_req 0 : BaseReq
		user_name 1 : string
		passwd 2 : string
	}
	response {
		base_resp 0 : BaseResp
	}
}

]]


proto.s2c = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

heartbeat 1 {}

perflop 2 {
	card_info 0 : *integer
}

.PlayerInfo {
	name 0 : string
	icon 1 : string #头像url
	money 2 : integer 
	odds 3 : integer #赔率
	is_leader 4 : boolean #是不是庄
}

#同步房间内信息
update_player_info 3  {
	room_id 0 : integer
	room_odds 1 : integer
	players 2 : *PlayerInfo
}

]]

return proto
