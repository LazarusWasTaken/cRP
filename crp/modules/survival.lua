local cfg = module("cfg/survival")
local lang = cRP.lang

-- api

function cRP.getHunger(user_id)
  local data = cRP.getUserDataTable(user_id)
  if data then
    return data.hunger
  end

  return 0
end

function cRP.getThirst(user_id)
  local data = cRP.getUserDataTable(user_id)
  if data then
    return data.thirst
  end

  return 0
end

function cRP.setHunger(user_id,value)
  local data = cRP.getUserDataTable(user_id)
  if data then
    data.hunger = value
    if data.hunger < 0 then data.hunger = 0
    elseif data.hunger > 100 then data.hunger = 100 
    end

    -- update bar
    local source = cRP.getUserSource(user_id)
    cRPclient._setProgressBarValue(source, "cRP:hunger",data.hunger)
    if data.hunger >= 100 then
      cRPclient._setProgressBarText(source,"cRP:hunger",lang.survival.starving())
    else
      cRPclient._setProgressBarText(source,"cRP:hunger","")
    end
  end
end

function cRP.setThirst(user_id,value)
  local data = cRP.getUserDataTable(user_id)
  if data then
    data.thirst = value
    if data.thirst < 0 then data.thirst = 0
    elseif data.thirst > 100 then data.thirst = 100 
    end

    -- update bar
    local source = cRP.getUserSource(user_id)
    cRPclient._setProgressBarValue(source, "cRP:thirst",data.thirst)
    if data.thirst >= 100 then
      cRPclient._setProgressBarText(source,"cRP:thirst",lang.survival.thirsty())
    else
      cRPclient._setProgressBarText(source,"cRP:thirst","")
    end
  end
end

function cRP.varyHunger(user_id, variation)
  local data = cRP.getUserDataTable(user_id)
  if data then
    local was_starving = data.hunger >= 100
    data.hunger = data.hunger + variation
    local is_starving = data.hunger >= 100

    -- apply overflow as damage
    local overflow = data.hunger-100
    if overflow > 0 then
      cRPclient._varyHealth(cRP.getUserSource(user_id),-overflow*cfg.overflow_damage_factor)
    end

    if data.hunger < 0 then data.hunger = 0
    elseif data.hunger > 100 then data.hunger = 100 
    end

    -- set progress bar data
    local source = cRP.getUserSource(user_id)
    cRPclient._setProgressBarValue(source,"cRP:hunger",data.hunger)
    if was_starving and not is_starving then
      cRPclient._setProgressBarText(source,"cRP:hunger","")
    elseif not was_starving and is_starving then
      cRPclient._setProgressBarText(source,"cRP:hunger",lang.survival.starving())
    end
  end
end

function cRP.varyThirst(user_id, variation)
  local data = cRP.getUserDataTable(user_id)
  if data then
    local was_thirsty = data.thirst >= 100
    data.thirst = data.thirst + variation
    local is_thirsty = data.thirst >= 100

    -- apply overflow as damage
    local overflow = data.thirst-100
    if overflow > 0 then
      cRPclient._varyHealth(cRP.getUserSource(user_id),-overflow*cfg.overflow_damage_factor)
    end

    if data.thirst < 0 then data.thirst = 0
    elseif data.thirst > 100 then data.thirst = 100 
    end

    -- set progress bar data
    local source = cRP.getUserSource(user_id)
    cRPclient._setProgressBarValue(source,"cRP:thirst",data.thirst)
    if was_thirsty and not is_thirsty then
      cRPclient._setProgressBarText(source,"cRP:thirst","")
    elseif not was_thirsty and is_thirsty then
      cRPclient._setProgressBarText(source,"cRP:thirst",lang.survival.thirsty())
    end
  end
end

-- tunnel api (expose some functions to clients)

function tcRP.varyHunger(variation)
  local user_id = cRP.getUserId(source)
  if user_id then
    cRP.varyHunger(user_id,variation)
  end
end

function tcRP.varyThirst(variation)
  local user_id = cRP.getUserId(source)
  if user_id then
    cRP.varyThirst(user_id,variation)
  end
end

-- tasks

-- hunger/thirst increase
function task_update()
  for k,v in pairs(cRP.users) do
    cRP.varyHunger(v,cfg.hunger_per_minute)
    cRP.varyThirst(v,cfg.thirst_per_minute)
  end

  SetTimeout(60000,task_update)
end

async(function()
  task_update()
end)

-- handlers

-- init values
AddEventHandler("cRP:playerJoin",function(user_id,source,name,last_login)
  local data = cRP.getUserDataTable(user_id)
  if data.hunger == nil then
    data.hunger = 0
    data.thirst = 0
  end
end)

-- add survival progress bars on spawn
AddEventHandler("cRP:playerSpawn",function(user_id, source, first_spawn)
  local data = cRP.getUserDataTable(user_id)

  -- disable police
  cRPclient._setPolice(source,cfg.police)
  -- set friendly fire
  cRPclient._setFriendlyFire(source,cfg.pvp)

  cRPclient._setProgressBar(source,"cRP:hunger","minimap",htxt,255,153,0,0)
  cRPclient._setProgressBar(source,"cRP:thirst","minimap",ttxt,0,125,255,0)
  cRP.setHunger(user_id, data.hunger)
  cRP.setThirst(user_id, data.thirst)
end)

-- EMERGENCY

---- revive
local revive_seq = {
  {"amb@medic@standing@kneel@enter","enter",1},
  {"amb@medic@standing@kneel@idle_a","idle_a",1},
  {"amb@medic@standing@kneel@exit","exit",1}
}

local choice_revive = {function(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local nplayer = cRPclient.getNearestPlayer(player,10)
      local nuser_id = cRP.getUserId(nplayer)
      if nuser_id then
        if cRPclient.isInComa(nplayer) then
            if cRP.tryGetInventoryItem(user_id,"medkit",1,true) then
              cRPclient._playAnim(player,false,revive_seq,false) -- anim
              SetTimeout(15000, function()
                cRPclient._varyHealth(nplayer,50) -- heal 50
              end)
            end
          else
            cRPclient._notify(player,lang.emergency.menu.revive.not_in_coma())
          end
      else
        cRPclient._notify(player,lang.common.no_player_near())
      end
  end
end,lang.emergency.menu.revive.description()}

-- add choices to the main menu (emergency)
cRP.registerMenuBuilder("main", function(add, data)
  local user_id = cRP.getUserId(data.player)
  if user_id then
    local choices = {}
    if cRP.hasPermission(user_id,"emergency.revive") then
      choices[lang.emergency.menu.revive.title()] = choice_revive
    end

    add(choices)
  end
end)
