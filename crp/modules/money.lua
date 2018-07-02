local lang = cRP.lang

-- Money module, wallet/bank API
-- The money is managed with direct SQL requests to prevent most potential value corruptions
-- the wallet empty itself when respawning (after death)

cRP.prepare("cRP/money_tables", [[
CREATE TABLE IF NOT EXISTS cRP_user_moneys(
  user_id INTEGER,
  wallet INTEGER,
  bank INTEGER,
  CONSTRAINT pk_user_moneys PRIMARY KEY(user_id),
  CONSTRAINT fk_user_moneys_users FOREIGN KEY(user_id) REFERENCES cRP_users(id) ON DELETE CASCADE
);
]])

cRP.prepare("cRP/money_init_user","INSERT IGNORE INTO cRP_user_moneys(user_id,wallet,bank) VALUES(@user_id,@wallet,@bank)")
cRP.prepare("cRP/get_money","SELECT wallet,bank FROM cRP_user_moneys WHERE user_id = @user_id")
cRP.prepare("cRP/set_money","UPDATE cRP_user_moneys SET wallet = @wallet, bank = @bank WHERE user_id = @user_id")

-- init tables
async(function()
  cRP.execute("cRP/money_tables")
end)

-- load config
local cfg = module("cfg/money")

-- API

-- get money
-- cbreturn nil if error
function cRP.getMoney(user_id)
  local tmp = cRP.getUserTmpTable(user_id)
  if tmp then
    return tmp.wallet or 0
  else
    return 0
  end
end

-- set money
function cRP.setMoney(user_id,value)
  local tmp = cRP.getUserTmpTable(user_id)
  if tmp then
    tmp.wallet = value
  end

  -- update client display
  local source = cRP.getUserSource(user_id)
  if source then
    cRPclient._setDivContent(source,"money",lang.money.display({value}))
  end
end

-- try a payment
-- return true or false (debited if true)
function cRP.tryPayment(user_id,amount)
  local money = cRP.getMoney(user_id)
  if amount >= 0 and money >= amount then
    cRP.setMoney(user_id,money-amount)
    return true
  else
    return false
  end
end

-- give money
function cRP.giveMoney(user_id,amount)
  if amount > 0 then
    local money = cRP.getMoney(user_id)
    cRP.setMoney(user_id,money+amount)
  end
end

-- get bank money
function cRP.getBankMoney(user_id)
  local tmp = cRP.getUserTmpTable(user_id)
  if tmp then
    return tmp.bank or 0
  else
    return 0
  end
end

-- set bank money
function cRP.setBankMoney(user_id,value)
  local tmp = cRP.getUserTmpTable(user_id)
  if tmp then
    tmp.bank = value
  end
end

-- give bank money
function cRP.giveBankMoney(user_id,amount)
  if amount > 0 then
    local money = cRP.getBankMoney(user_id)
    cRP.setBankMoney(user_id,money+amount)
  end
end

-- try a withdraw
-- return true or false (withdrawn if true)
function cRP.tryWithdraw(user_id,amount)
  local money = cRP.getBankMoney(user_id)
  if amount >= 0 and money >= amount then
    cRP.setBankMoney(user_id,money-amount)
    cRP.giveMoney(user_id,amount)
    return true
  else
    return false
  end
end

-- try a deposit
-- return true or false (deposited if true)
function cRP.tryDeposit(user_id,amount)
  if amount >= 0 and cRP.tryPayment(user_id,amount) then
    cRP.giveBankMoney(user_id,amount)
    return true
  else
    return false
  end
end

-- try full payment (wallet + bank to complete payment)
-- return true or false (debited if true)
function cRP.tryFullPayment(user_id,amount)
  local money = cRP.getMoney(user_id)
  if money >= amount then -- enough, simple payment
    return cRP.tryPayment(user_id, amount)
  else  -- not enough, withdraw -> payment
    if cRP.tryWithdraw(user_id, amount-money) then -- withdraw to complete amount
      return cRP.tryPayment(user_id, amount)
    end
  end

  return false
end

-- events, init user account if doesn't exist at connection
AddEventHandler("cRP:playerJoin",function(user_id,source,name,last_login)
  cRP.execute("cRP/money_init_user", {user_id = user_id, wallet = cfg.open_wallet, bank = cfg.open_bank})
  -- load money (wallet,bank)
  local tmp = cRP.getUserTmpTable(user_id)
  if tmp then
    local rows = cRP.query("cRP/get_money", {user_id = user_id})
    if #rows > 0 then
      tmp.bank = rows[1].bank
      tmp.wallet = rows[1].wallet
    end
  end
end)

-- save money on leave
AddEventHandler("cRP:playerLeave",function(user_id,source)
  -- (wallet,bank)
  local tmp = cRP.getUserTmpTable(user_id)
  if tmp and tmp.wallet and tmp.bank then
    cRP.execute("cRP/set_money", {user_id = user_id, wallet = tmp.wallet, bank = tmp.bank})
  end
end)

-- save money (at same time that save datatables)
AddEventHandler("cRP:save", function()
  for k,v in pairs(cRP.user_tmp_tables) do
    if v.wallet and v.bank then
      cRP.execute("cRP/set_money", {user_id = k, wallet = v.wallet, bank = v.bank})
    end
  end
end)

-- money hud
AddEventHandler("cRP:playerSpawn",function(user_id, source, first_spawn)
  if first_spawn then
    -- add money display
    cRPclient._setDiv(source,"money",cfg.display_css,lang.money.display({cRP.getMoney(user_id)}))
  end
end)

local function ch_give(player,choice)
  -- get nearest player
  local user_id = cRP.getUserId(player)
  if user_id then
    local nplayer = cRPclient.getNearestPlayer(player,10)
    if nplayer then
      local nuser_id = cRP.getUserId(nplayer)
      if nuser_id then
        -- prompt number
        local amount = cRP.prompt(player,lang.money.give.prompt(),"")
        local amount = parseInt(amount)
        if amount > 0 and cRP.tryPayment(user_id,amount) then
          cRP.giveMoney(nuser_id,amount)
          cRPclient._notify(player,lang.money.given({amount}))
          cRPclient._notify(nplayer,lang.money.received({amount}))
        else
          cRPclient._notify(player,lang.money.not_enough())
        end
      else
        cRPclient._notify(player,lang.common.no_player_near())
      end
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end

-- add player give money to main menu
cRP.registerMenuBuilder("main", function(add, data)
  local user_id = cRP.getUserId(data.player)
  if user_id then
    local choices = {}
    choices[lang.money.give.title()] = {ch_give, lang.money.give.description()}

    add(choices)
  end
end)
