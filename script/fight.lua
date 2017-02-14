local skynet = require "skynet"
local CardCfg = require "card_cfg"
local net = require "net"
local class = require "class"
local FightMgr = require "fight_mgr"

local Battle = class()
local Player = class()
local Card = class()
local Grid = class()
local Board = class()
local ServerEvHandler = class()

local MAX_ROW = 4
local MAX_COL = 4
local MAX_CARD_NUM = 5

local g_battle = Battle.new()

local function transBoolNum(boolVar)
    return boolVar and 1 or 0
end

local function dumpGrid(grid)
    local card = grid.card_
    print("dumpGrid:", grid, grid.row_, grid.col_, card)
    if card then
        print('dumpCard:', card.owner_, card.index_, card.roletype_, card.atk_, card.def_, card.ris_)
        print(transBoolNum(card.conn_["LT"])..' '..transBoolNum(card.conn_["TM"])..' '..transBoolNum(card.conn_["RT"]))
        print(transBoolNum(card.conn_["LM"])..' - '..transBoolNum(card.conn_["RM"]))
        print(transBoolNum(card.conn_["LB"])..' '..transBoolNum(card.conn_["BM"])..' '..transBoolNum(card.conn_["RB"]))
    end
end

function ServerEvHandler:onStart(owner_1, owner_2, turn)
    print('onStart:', owner_1, owner_2, turn)
    local p1 = assert(g_battle:getPlayer(owner_1))
    local p2 = assert(g_battle:getPlayer(owner_2))

    -- pack hand card
    local cid_tbl = {}
    for i = 1, MAX_CARD_NUM do
        cid_tbl[i] = p1.cards_[i].cardID_
    end
    net:getConn(p1.fd_):onFightStart(turn, owner_2, table.concat(cid_tbl, '#'))

    cid_tbl = {}
    for i = 1, MAX_CARD_NUM do
        cid_tbl[i] = p2.cards_[i].cardID_
    end
    net:getConn(p2.fd_):onFightStart(turn, owner_1, table.concat(cid_tbl, '#'))
end

function ServerEvHandler:onSetCard(owner, grid, card)
    print('onSetCard')
    dumpGrid(grid)
    for uid, player in pairs(g_battle.players_) do
        net:getConn(player.fd_):onPlaceCard(owner, card.cardID_, card.index_, grid.row_, grid.col_)
    end
end

function ServerEvHandler:onCaptured(srcGrid, dstGrid)
    print('onCaptured')
    dumpGrid(srcGrid)
    dumpGrid(dstGrid)
end

function ServerEvHandler:onWaitSelect(owner, fight_set)
    print('onWaitSelect', #fight_set)
    for _, grid in ipairs(fight_set) do
        dumpGrid(grid)
    end
end

function ServerEvHandler:onSelectFight(owner, idx, fight_set)
    for uid, player in pairs(g_battle.players_) do
        net:getConn(player.fd_):onSelectFight(owner, idx)
    end
end

function ServerEvHandler:onWinFight(srcGrid, dstGrid)
    print('onWinFight')
    dumpGrid(srcGrid)
    dumpGrid(dstGrid)
end

function ServerEvHandler:onLoseFight(srcGrid, dstGrid)
    print('onLoseFight')
    dumpGrid(srcGrid)
    dumpGrid(dstGrid)
end

function ServerEvHandler:onLoseFight(srcGrid, dstGrid)
    print('onLoseFight')
    dumpGrid(srcGrid)
    dumpGrid(dstGrid)
end

function ServerEvHandler:onGameOver(winner, scoreWin, scoreLose)
    print('onGameOver', winner, scoreWin, scoreLose)
    for uid, player in pairs(g_battle.players_) do
        skynet.call(player.agent_, "game", "leaveFight")
    end
    skynet.exit()
end

function ServerEvHandler:onTurnChanged(owner)
    print('onTurnChanged', owner)
    for uid, player in pairs(g_battle.players_) do
        net:getConn(player.fd_):onTurnBegin(owner)
    end
end

function Card:ctor(index, cid, owner)
    self.index_ = index
    self.cardID_ = cid
    self.owner_ = owner

    local cardBaseCfg = CardCfg:getCardBaseCfg(self.cardID_)
    local cardAttrCfg = CardCfg:getCardAttrCfg(self.cardID_)
    local cardDirCfg = CardCfg:getCardDirCfg(self.cardID_)

    self.atk_ = cardAttrCfg('atk')
    self.def_ = cardAttrCfg('def')
    self.ris_ = cardAttrCfg('res')
    self.roletype_ = cardBaseCfg('roleType')

    self.conn_ = {}
    self.conn_.LM = cardDirCfg("LM")
    self.conn_.LT = cardDirCfg("LT")
    self.conn_.TM = cardDirCfg("TM")
    self.conn_.RT = cardDirCfg("RT")
    self.conn_.RM = cardDirCfg("RM")
    self.conn_.RB = cardDirCfg("RB")
    self.conn_.BM = cardDirCfg("BM")
    self.conn_.LB = cardDirCfg("LB")
end


function Grid:ctor(row, col)
    self.row_ = row
    self.col_ = col
    self.card_ = nil
end

function Player:ctor(p)
    self.agent_ = p.agent
    self.fd_ = p.fd
    self.cards_ = {}

    for i = 1, MAX_CARD_NUM do
        self.cards_[i] = Card.new(i, CardCfg:randomCardID(), p.uid)
    end
end

function Battle:start(c1, c2)
    print(' battle fight start ', c1.uid, c2.uid)
    
    self.players_ = {}
    self.players_[c1.uid] = Player.new(c1)
    self.players_[c2.uid] = Player.new(c2)

    self.grids_ = {}
    for row = 1,MAX_ROW do
        self.grids_[row] = self.grids_[row] or {}
        for col = 1, MAX_COL do
            self.grids_[row][col] = Grid.new(row, col)
        end
    end

    self.handler_ = ServerEvHandler.new()
    self.fightMgr_ = FightMgr.new(c1.uid, self.players_[c1.uid].cards_, 
        c2.uid, self.players_[c2.uid].cards_, self.grids_, MAX_ROW, MAX_COL, self.handler_)

    self.fightMgr_:start()
end

function Battle:getPlayer(uid)
    return self.players_[uid]
end

function Battle:placeCard(client, srcpos, row, col)
    print('placeCard', client.uid, srcpos, row, col)
    local ret, msg = self.fightMgr_:placeCard(client.uid, tonumber(srcpos), tonumber(row), tonumber(col))
    if msg then
        error(msg)
    end
end

function Battle:selectFight(client, idx)
    print('selectFight', client.uid, idx)
    self.fightMgr_:selectFight(client.uid, tonumber(idx))
end

function Battle:logout(client)
    for uid, player in pairs(self.players_) do
        if client.uid ~= uid then
	    skynet.call(player.agent_, "game", "leaveFight")
	    net:getConn(player.fd_):onEnemyLogout(client.uid)
	    return
	end
    end 
end

function Battle:pickCard(client, idx)
    for uid, player in pairs(self.players_) do
        if client.uid ~= uid then
            net:getConn(player.fd_):onPickCard(client.uid, idx)
            return
        end
    end
end

function Battle:dropCard(client, idx)
    for uid, player in pairs(self.players_) do
        if client.uid ~= uid then
	    print('dropCard in battle', client.uid, idx)
            net:getConn(player.fd_):onDropCard(client.uid, idx)
            return
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        print('fight service !')
        local f = g_battle[cmd]
        if f then
            local ok, result = pcall(f, g_battle, ...)
            if not ok then
                error(result)
            end
        else
            assert(false, 'cmd not support '..cmd)
        end
        skynet.ret()
    end)
end)
