
-- this module define some police tools and functions
local lang = cRP.lang
local cfg = module("cfg/police")

-- police records

-- insert a police record for a specific user
--- line: text for one line (can be html)
function cRP.insertPoliceRecord(user_id, line)
  if user_id then
    local data = cRP.getUData(user_id, "cRP:police_records")
    local records = data..line.."<br />"
    cRP.setUData(user_id, "cRP:police_records", records)
  end
end

-- police PC

local menu_pc = {name=lang.police.pc.title(),css={top="75px",header_color="rgba(0,125,255,0.75)"}}

-- search identity by registration
local function ch_searchreg(player,choice)
  local reg = cRP.prompt(player,lang.police.pc.searchreg.prompt(),"")
  local user_id = cRP.getUserByRegistration(reg)
  if user_id then
    local identity = cRP.getUserIdentity(user_id)
    if identity then
      -- display identity and business
      local name = identity.name
      local firstname = identity.firstname
      local age = identity.age
      local phone = identity.phone
      local registration = identity.registration
      local bname = ""
      local bcapital = 0
      local home = ""
      local number = ""

      local business = cRP.getUserBusiness(user_id)
      if business then
        bname = business.name
        bcapital = business.capital
      end

      local address = cRP.getUserAddress(user_id)
      if address then
        home = address.home
        number = address.number
      end

      local content = lang.police.identity.info({name,firstname,age,registration,phone,bname,bcapital,home,number})
      cRPclient._setDiv(player,"police_pc",".div_police_pc{ background-color: rgba(0,0,0,0.75); color: white; font-weight: bold; width: 500px; padding: 10px; margin: auto; margin-top: 150px; }",content)
    else
      cRPclient._notify(player,lang.common.not_found())
    end
  else
    cRPclient._notify(player,lang.common.not_found())
  end
end

-- show police records by registration
local function ch_show_police_records(player,choice)
  local reg = cRP.prompt(player,lang.police.pc.searchreg.prompt(),"")
  local user_id = cRP.getUserByRegistration(reg)
  if user_id then
    local content = cRP.getUData(user_id, "cRP:police_records")
    cRPclient._setDiv(player,"police_pc",".div_police_pc{ background-color: rgba(0,0,0,0.75); color: white; font-weight: bold; width: 500px; padding: 10px; margin: auto; margin-top: 150px; }",content)
  else
    cRPclient._notify(player,lang.common.not_found())
  end
end

-- delete police records by registration
local function ch_delete_police_records(player,choice)
  local reg = cRP.prompt(player,lang.police.pc.searchreg.prompt(),"")
  local user_id = cRP.getUserByRegistration(reg)
  if user_id then
    cRP.setUData(user_id, "cRP:police_records", "")
    cRPclient._notify(player,lang.police.pc.records.delete.deleted())
  else
    cRPclient._notify(player,lang.common.not_found())
  end
end

-- close business of an arrested owner
local function ch_closebusiness(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,5)
  local nuser_id = cRP.getUserId(nplayer)
  if nuser_id then
    local identity = cRP.getUserIdentity(nuser_id)
    local business = cRP.getUserBusiness(nuser_id)
    if identity and business then
      if cRP.request(player,lang.police.pc.closebusiness.request({identity.name,identity.firstname,business.name}),15) then
        cRP.closeBusiness(nuser_id)
        cRPclient._notify(player,lang.police.pc.closebusiness.closed())
      end
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  else
    cRPclient._notify(player,lang.common.no_player_near())
  end
end

-- track vehicle
local function ch_trackveh(player,choice)
  local reg = cRP.prompt(player,lang.police.pc.trackveh.prompt_reg(),"")
  local user_id = cRP.getUserByRegistration(reg)
  if user_id then
    local note = cRP.prompt(player,lang.police.pc.trackveh.prompt_note(),"")
    -- begin veh tracking
    cRPclient._notify(player,lang.police.pc.trackveh.tracking())
    local seconds = math.random(cfg.trackveh.min_time,cfg.trackveh.max_time)
    SetTimeout(seconds*1000,function()
      local tplayer = cRP.getUserSource(user_id)
      if tplayer then
        local ok,x,y,z = cRPclient.getAnyOwnedVehiclePosition(tplayer)
        if ok then -- track success
          cRP.sendServiceAlert(nil, cfg.trackveh.service,x,y,z,lang.police.pc.trackveh.tracked({reg,note}))
        else
          cRPclient._notify(player,lang.police.pc.trackveh.track_failed({reg,note})) -- failed
        end
      else
        cRPclient._notify(player,lang.police.pc.trackveh.track_failed({reg,note})) -- failed
      end
    end)
  else
    cRPclient._notify(player,lang.common.not_found())
  end
end

menu_pc[lang.police.pc.searchreg.title()] = {ch_searchreg,lang.police.pc.searchreg.description()}
menu_pc[lang.police.pc.trackveh.title()] = {ch_trackveh,lang.police.pc.trackveh.description()}
menu_pc[lang.police.pc.records.show.title()] = {ch_show_police_records,lang.police.pc.records.show.description()}
menu_pc[lang.police.pc.records.delete.title()] = {ch_delete_police_records, lang.police.pc.records.delete.description()}
menu_pc[lang.police.pc.closebusiness.title()] = {ch_closebusiness,lang.police.pc.closebusiness.description()}

menu_pc.onclose = function(player) -- close pc gui
  cRPclient._removeDiv(player,"police_pc")
end

local function pc_enter(source,area)
  local user_id = cRP.getUserId(source)
  if user_id and cRP.hasPermission(user_id,"police.pc") then
    cRP.openMenu(source,menu_pc)
  end
end

local function pc_leave(source,area)
  cRP.closeMenu(source)
end

-- main menu choices

---- handcuff
local choice_handcuff = {function(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,10)
  if nplayer then
    local nuser_id = cRP.getUserId(nplayer)
    if nuser_id then
      cRPclient._toggleHandcuff(nplayer)
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end,lang.police.menu.handcuff.description()}

---- drag
local choice_drag = {function(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,10)
  if nplayer then
    local nuser_id = cRP.getUserId(nplayer)
    if nuser_id then
      local followed = cRPclient.getFollowedPlayer(nplayer)
      if followed ~= player then -- drag
        cRPclient._followPlayer(nplayer, player)
      else -- stop follow
        cRPclient._followPlayer(nplayer)
      end
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end,lang.police.menu.drag.description()}

---- putinveh
--[[
-- veh at position version
local choice_putinveh = {function(player,choice)
  cRPclient.getNearestPlayer(player,{10},function(nplayer)
    local nuser_id = cRP.getUserId(nplayer)
    if nuser_id ~= nil then
      cRPclient.isHandcuffed(nplayer,{}, function(handcuffed)  -- check handcuffed
        if handcuffed then
          cRPclient.getNearestOwnedVehicle(player, {10}, function(ok,vtype,name) -- get nearest owned vehicle
            if ok then
              cRPclient.getOwnedVehiclePosition(player, {vtype}, function(x,y,z)
                cRPclient.putInVehiclePositionAsPassenger(nplayer,{x,y,z}) -- put player in vehicle
              end)
            else
              cRPclient._notify(player,lang.vehicle.no_owned_near())
            end
          end)
        else
          cRPclient._notify(player,lang.police.not_handcuffed())
        end
      end)
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end)
end,lang.police.menu.putinveh.description()}
--]]

local choice_putinveh = {function(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,10)
  local nuser_id = cRP.getUserId(nplayer)
  if nuser_id then
    if cRPclient.isHandcuffed(nplayer) then  -- check handcuffed
      cRPclient._putInNearestVehicleAsPassenger(nplayer, 5)
    else
      cRPclient._notify(player,lang.police.not_handcuffed())
    end
  else
    cRPclient._notify(player,lang.common.no_player_near())
  end
end,lang.police.menu.putinveh.description()}

local choice_getoutveh = {function(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,10)
  local nuser_id = cRP.getUserId(nplayer)
  if nuser_id then
    if cRPclient.isHandcuffed(nplayer) then  -- check handcuffed
      cRPclient._ejectVehicle(nplayer)
    else
      cRPclient._notify(player,lang.police.not_handcuffed())
    end
  else
    cRPclient._notify(player,lang.common.no_player_near())
  end
end,lang.police.menu.getoutveh.description()}

---- askid
local choice_askid = {function(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,10)
  local nuser_id = cRP.getUserId(nplayer)
  if nuser_id then
    cRPclient._notify(player,lang.police.menu.askid.asked())
    if cRP.request(nplayer,lang.police.menu.askid.request(),15) then
      local identity = cRP.getUserIdentity(nuser_id)
      if identity then
        -- display identity and business
        local name = identity.name
        local firstname = identity.firstname
        local age = identity.age
        local phone = identity.phone
        local registration = identity.registration
        local bname = ""
        local bcapital = 0
        local home = ""
        local number = ""

        local business = cRP.getUserBusiness(nuser_id)
        if business then
          bname = business.name
          bcapital = business.capital
        end

        local address = cRP.getUserAddress(nuser_id)
        if address then
          home = address.home
          number = address.number
        end

        local content = lang.police.identity.info({name,firstname,age,registration,phone,bname,bcapital,home,number})
        cRPclient._setDiv(player,"police_identity",".div_police_identity{ background-color: rgba(0,0,0,0.75); color: white; font-weight: bold; width: 500px; padding: 10px; margin: auto; margin-top: 150px; }",content)
        -- request to hide div
        cRP.request(player, lang.police.menu.askid.request_hide(), 1000)
        cRPclient._removeDiv(player,"police_identity")
      end
    else
      cRPclient._notify(player,lang.common.request_refused())
    end
  else
    cRPclient._notify(player,lang.common.no_player_near())
  end
end, lang.police.menu.askid.description()}

---- police check
local choice_check = {function(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,5)
  local nuser_id = cRP.getUserId(nplayer)
  if nuser_id then
    cRPclient._notify(nplayer,lang.police.menu.check.checked())
    local weapons = cRPclient.getWeapons(nplayer)
    -- prepare display data (money, items, weapons)
    local money = cRP.getMoney(nuser_id)
    local items = ""
    local data = cRP.getUserDataTable(nuser_id)
    if data and data.inventory then
      for k,v in pairs(data.inventory) do
        local item_name, item_desc, item_weight = cRP.getItemDefinition(k)
        if item_name then
          items = items.."<br />"..item_name.." ("..v.amount..")"
        end
      end
    end

    local weapons_info = ""
    for k,v in pairs(weapons) do
      weapons_info = weapons_info.."<br />"..k.." ("..v.ammo..")"
    end

    cRPclient._setDiv(player,"police_check",".div_police_check{ background-color: rgba(0,0,0,0.75); color: white; font-weight: bold; width: 500px; padding: 10px; margin: auto; margin-top: 150px; }",lang.police.menu.check.info({money,items,weapons_info}))
    -- request to hide div
    cRP.request(player, lang.police.menu.check.request_hide(), 1000)
    cRPclient._removeDiv(player,"police_check")
  else
    cRPclient._notify(player,lang.common.no_player_near())
  end
end, lang.police.menu.check.description()}

local choice_seize_weapons = {function(player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local nplayer = cRPclient.getNearestPlayer(player, 5)
    local nuser_id = cRP.getUserId(nplayer)
    if nuser_id and cRP.hasPermission(nuser_id, "police.seizable") then
      if cRPclient.isHandcuffed(nplayer) then  -- check handcuffed
        local weapons = cRPclient.getWeapons(nplayer)
        for k,v in pairs(weapons) do -- display seized weapons
          -- cRPclient._notify(player,lang.police.menu.seize.seized({k,v.ammo}))
          -- convert weapons to parametric weapon items
          cRP.giveInventoryItem(user_id, "wbody|"..k, 1, true)
          if v.ammo > 0 then
            cRP.giveInventoryItem(user_id, "wammo|"..k, v.ammo, true)
          end
        end

        -- clear all weapons
        cRPclient._giveWeapons(nplayer,{},true)
        cRPclient._notify(nplayer,lang.police.menu.seize.weapons.seized())
      else
        cRPclient._notify(player,lang.police.not_handcuffed())
      end
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end, lang.police.menu.seize.weapons.description()}

local choice_seize_items = {function(player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local nplayer = cRPclient.getNearestPlayer(player, 5)
    local nuser_id = cRP.getUserId(nplayer)
    if nuser_id and cRP.hasPermission(nuser_id, "police.seizable") then
      if cRPclient.isHandcuffed(nplayer) then  -- check handcuffed
        local inv = cRP.getInventory(user_id)

        for k,v in pairs(cfg.seizable_items) do -- transfer seizable items
          local sub_items = {v} -- single item

          if string.sub(v,1,1) == "*" then -- seize all parametric items of this idname
            local idname = string.sub(v,2)
            sub_items = {}
            for fidname,_ in pairs(inv) do
              if splitString(fidname, "|")[1] == idname then -- same parametric item
                table.insert(sub_items, fidname) -- add full idname
              end
            end
          end

          for _,idname in pairs(sub_items) do
            local amount = cRP.getInventoryItemAmount(nuser_id,idname)
            if amount > 0 then
              local item_name, item_desc, item_weight = cRP.getItemDefinition(idname)
              if item_name then -- do transfer
                if cRP.tryGetInventoryItem(nuser_id,idname,amount,true) then
                  cRP.giveInventoryItem(user_id,idname,amount,false)
                  cRPclient._notify(player,lang.police.menu.seize.seized({item_name,amount}))
                end
              end
            end
          end
        end

        cRPclient._notify(nplayer,lang.police.menu.seize.items.seized())
      else
        cRPclient._notify(player,lang.police.not_handcuffed())
      end
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end, lang.police.menu.seize.items.description()}

-- toggle jail nearest player
local choice_jail = {function(player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local nplayer = cRPclient.getNearestPlayer(player, 5)
    local nuser_id = cRP.getUserId(nplayer)
    if nuser_id then
      if cRPclient.isJailed(nplayer) then
        cRPclient._unjail(nplayer)
        cRPclient._notify(nplayer,lang.police.menu.jail.notify_unjailed())
        cRPclient._notify(player,lang.police.menu.jail.unjailed())
      else -- find the nearest jail
        local x,y,z = cRPclient.getPosition(nplayer)
        local d_min = 1000
        local v_min = nil
        for k,v in pairs(cfg.jails) do
          local dx,dy,dz = x-v[1],y-v[2],z-v[3]
          local dist = math.sqrt(dx*dx+dy*dy+dz*dz)

          if dist <= d_min and dist <= 15 then -- limit the research to 15 meters
            d_min = dist
            v_min = v
          end

          -- jail
          if v_min then
            cRPclient._jail(nplayer,v_min[1],v_min[2],v_min[3],v_min[4])
            cRPclient._notify(nplayer,lang.police.menu.jail.notify_jailed())
            cRPclient._notify(player,lang.police.menu.jail.jailed())
          else
            cRPclient._notify(player,lang.police.menu.jail.not_found())
          end
        end
      end
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end, lang.police.menu.jail.description()}

local choice_fine = {function(player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local nplayer = cRPclient.getNearestPlayer(player, 5)
    local nuser_id = cRP.getUserId(nplayer)
    if nuser_id then
      local money = cRP.getMoney(nuser_id)+cRP.getBankMoney(nuser_id)

      -- build fine menu
      local menu = {name=lang.police.menu.fine.title(),css={top="75px",header_color="rgba(0,125,255,0.75)"}}

      local choose = function(player,choice) -- fine action
        local amount = cfg.fines[choice]
        if amount ~= nil then
          if cRP.tryFullPayment(nuser_id, amount) then
            cRP.insertPoliceRecord(nuser_id, lang.police.menu.fine.record({choice,amount}))
            cRPclient._notify(player,lang.police.menu.fine.fined({choice,amount}))
            cRPclient._notify(nplayer,lang.police.menu.fine.notify_fined({choice,amount}))
            cRP.closeMenu(player)
          else
            cRPclient._notify(player,lang.money.not_enough())
          end
        end
      end

      for k,v in pairs(cfg.fines) do -- add fines in function of money available
        if v <= money then
          menu[k] = {choose,v}
        end
      end

      -- open menu
      cRP.openMenu(player, menu)
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end, lang.police.menu.fine.description()}

local choice_store_weapons = {function(player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local weapons = cRPclient.getWeapons(player)
    for k,v in pairs(weapons) do
      -- convert weapons to parametric weapon items
      cRP.giveInventoryItem(user_id, "wbody|"..k, 1, true)
      if v.ammo > 0 then
        cRP.giveInventoryItem(user_id, "wammo|"..k, v.ammo, true)
      end
    end

    -- clear all weapons
    cRPclient._giveWeapons(player,{},true)
  end
end, lang.police.menu.store_weapons.description()}

-- add choices to the menu
cRP.registerMenuBuilder("main", function(add, data)
  local player = data.player

  local user_id = cRP.getUserId(player)
  if user_id then
    local choices = {}

    if cRP.hasPermission(user_id,"police.menu") then
      -- build police menu
      choices[lang.police.title()] = {function(player,choice)
        local menu = cRP.buildMenu("police", {player = player})
        menu.name = lang.police.title()
        menu.css = {top="75px",header_color="rgba(0,125,255,0.75)"}

        if cRP.hasPermission(user_id,"police.handcuff") then
          menu[lang.police.menu.handcuff.title()] = choice_handcuff
        end

        if cRP.hasPermission(user_id,"police.drag") then
          menu[lang.police.menu.drag.title()] = choice_drag
        end

        if cRP.hasPermission(user_id,"police.putinveh") then
          menu[lang.police.menu.putinveh.title()] = choice_putinveh
        end

        if cRP.hasPermission(user_id,"police.getoutveh") then
          menu[lang.police.menu.getoutveh.title()] = choice_getoutveh
        end

        if cRP.hasPermission(user_id,"police.check") then
          menu[lang.police.menu.check.title()] = choice_check
        end

        if cRP.hasPermission(user_id,"police.seize.weapons") then
          menu[lang.police.menu.seize.weapons.title()] = choice_seize_weapons
        end

        if cRP.hasPermission(user_id,"police.seize.items") then
          menu[lang.police.menu.seize.items.title()] = choice_seize_items
        end

        if cRP.hasPermission(user_id,"police.jail") then
          menu[lang.police.menu.jail.title()] = choice_jail
        end

        if cRP.hasPermission(user_id,"police.fine") then
          menu[lang.police.menu.fine.title()] = choice_fine
        end

        cRP.openMenu(player,menu)
      end}
    end

    if cRP.hasPermission(user_id,"police.askid") then
      choices[lang.police.menu.askid.title()] = choice_askid
    end

    if cRP.hasPermission(user_id, "police.store_weapons") then
      choices[lang.police.menu.store_weapons.title()] = choice_store_weapons
    end

    add(choices)
  end
end)

local function build_client_points(source)
  -- PC
  for k,v in pairs(cfg.pcs) do
    local x,y,z = table.unpack(v)
    cRPclient._addMarker(source,x,y,z-1,0.7,0.7,0.5,0,125,255,125,150)
    cRP.setArea(source,"cRP:police:pc"..k,x,y,z,1,1.5,pc_enter,pc_leave)
  end
end

-- build police points
AddEventHandler("cRP:playerSpawn",function(user_id, source, first_spawn)
  if first_spawn then
    build_client_points(source)
  end
end)

-- WANTED SYNC

local wantedlvl_players = {}

function cRP.getUserWantedLevel(user_id)
  return wantedlvl_players[user_id] or 0
end

-- receive wanted level
function tcRP.updateWantedLevel(level)
  local player = source
  local user_id = cRP.getUserId(player)
  if user_id then
    local was_wanted = (cRP.getUserWantedLevel(user_id) > 0)
    wantedlvl_players[user_id] = level
    local is_wanted = (level > 0)

    -- send wanted to listening service
    if not was_wanted and is_wanted then
      local x,y,z = cRPclient.getPosition(player)
      cRP.sendServiceAlert(nil, cfg.wanted.service,x,y,z,lang.police.wanted({level}))
    end

    if was_wanted and not is_wanted then
      cRPclient._removeNamedBlip(-1, "cRP:wanted:"..user_id) -- remove wanted blip (all to prevent phantom blip)
    end
  end
end

-- delete wanted entry on leave
AddEventHandler("cRP:playerLeave", function(user_id, player)
  wantedlvl_players[user_id] = nil
  cRPclient._removeNamedBlip(-1, "cRP:wanted:"..user_id)  -- remove wanted blip (all to prevent phantom blip)
end)

-- display wanted positions
local function task_wanted_positions()
  local listeners = cRP.getUsersByPermission("police.wanted")
  for k,v in pairs(wantedlvl_players) do -- each wanted player
    local player = cRP.getUserSource(tonumber(k))
    if player and v and v > 0 then
      local x,y,z = cRPclient.getPosition(player)
      for l,w in pairs(listeners) do -- each listening player
        local lplayer = cRP.getUserSource(w)
        if lplayer then
          cRPclient._setNamedBlip(lplayer, "cRP:wanted:"..k,x,y,z,cfg.wanted.blipid,cfg.wanted.blipcolor,lang.police.wanted({v}))
        end
      end
    end
  end
  SetTimeout(5000, task_wanted_positions)
end

async(function()
  task_wanted_positions()
end)
