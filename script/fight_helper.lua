local skynet = require "skynet"
local math = require "math"
local logger = require "logger"


--返回牛几和最大的牌是啥
function parse_card_info(card_lst)
	local has_niu = false

	assert(#card_lst == 5)
	--暴力找牛,共6种组合
	local sum = 0
	for i = 1, 3, 1 do
		for j = i + 1, 4, 1 do
			for k = j + 1, 5, 1 do
				sum = transCard(card_lst[i]) + transCard(card_lst[j]) + transCard(card_lst[k])
				if sum % 10 == 0 then
					has_niu = true
					break
				end
			end
		end
	end

	--找最大的牌
	max_card = 0
	sum = 0
	for i = 1, 5, 1 do
		if card_lst[i] > max_card then
			max_card = card_lst[i]
			sum = sum + transCard(card_lst[i])
		end
	end

	if has_niu == true then
		if sum % 10 == 0 then
			sum = 10
		else
			sum = sum % 10
		end
		return sum, max_card
	else
		return 0, max_card
	end
end

function transCard(card_num)
	if (card_num - 1) % 13 + 1 >= 10 then
		return 10
	end

	return (card_num - 1) % 13 + 1 
end

--获取牛的赔率
function get_card_odds(niu_num)
	if niu_num == 10 then
		return 3
	end

	if niu_num > 6 then
		return 2
	end

	return 1
end
