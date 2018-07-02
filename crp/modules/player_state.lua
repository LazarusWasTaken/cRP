local cfg = module("cfg/player_state")
local lang = cRP.lang

-- client -> server events
AddEventHandler("cRP:playerSpawn", function(user_id, source, first_spawn)
  local player = source
  local data = cRP.getUserDataTable(user_id)
  local tmpdata = cRP.getUserTmpTable(user_id)

  if first_spawn then -- first spawn
    -- cascade load customization then weapons
    if data.customization == nil then
      data.customization = cfg.default_customization
    end

    if not data.position and cfg.spawn_enabled then
      local x = cfg.spawn_position[1]+math.random()*cfg.spawn_radius*2-cfg.spawn_radius
      local y = cfg.spawn_position[2]+math.random()*cfg.spawn_radius*2-cfg.spawn_radius
      local z = cfg.spawn_position[3]+math.random()*cfg.spawn_radius*2-cfg.spawn_radius
      data.position = {x=x,y=y,z=z}
    end

    if data.position then -- teleport to saved pos
      cRPclient.teleport(source,data.position.x,data.position.y,data.position.z)
    end

    if data.customization then
      cRPclient.setCustomization(source,data.customization) 
      if data.weapons then -- load saved weapons
        cRPclient.giveWeapons(source,data.weapons,true)

        if data.health then -- set health
          cRPclient.setHealth(source,data.health)
          SetTimeout(5000, function() -- check coma, kill if in coma
            if cRPclient.isInComa(player) then
              cRPclient.killComa(player)
            end
          end)
        end
      end
    else
      if data.weapons then -- load saved weapons
        cRPclient.giveWeapons(source,data.weapons,true)
      end

      if data.health then
        cRPclient.setHealth(source,data.health)
      end
    end


    -- notify last login
    SetTimeout(15000,function()
      cRPclient._notify(player,lang.common.welcome({tmpdata.last_login}))
    end)
  else -- not first spawn (player died), don't load weapons, empty wallet, empty inventory
    cRP.setHunger(user_id,0)
    cRP.setThirst(user_id,0)
    cRP.clearInventory(user_id)

    if cfg.clear_phone_directory_on_death then
      data.phone_directory = {} -- clear phone directory after death
    end

    if cfg.lose_aptitudes_on_death then
      data.gaptitudes = {} -- clear aptitudes after death
    end

    cRP.setMoney(user_id,0)

    -- disable handcuff
    cRPclient._setHandcuffed(player,false)

    if cfg.spawn_enabled then -- respawn
      local x = cfg.spawn_position[1]+math.random()*cfg.spawn_radius*2-cfg.spawn_radius
      local y = cfg.spawn_position[2]+math.random()*cfg.spawn_radius*2-cfg.spawn_radius
      local z = cfg.spawn_position[3]+math.random()*cfg.spawn_radius*2-cfg.spawn_radius
      data.position = {x=x,y=y,z=z}
      cRPclient._teleport(source,x,y,z)
    end

    -- load character customization
    if data.customization then
      cRPclient._setCustomization(source,data.customization)
    end
  end

  cRPclient._playerStateReady(source, true)
end)

-- updates

function tcRP.updatePos(x,y,z)
  local user_id = cRP.getUserId(source)
  if user_id then
    local data = cRP.getUserDataTable(user_id)
    local tmp = cRP.getUserTmpTable(user_id)
    if data and (not tmp or not tmp.home_stype) then -- don't save position if inside home slot
      data.position = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
    end
  end
end

function tcRP.updateWeapons(weapons)
  local user_id = cRP.getUserId(source)
  if user_id then
    local data = cRP.getUserDataTable(user_id)
    if data then
      data.weapons = weapons
    end
  end
end

function tcRP.updateCustomization(customization)
  local user_id = cRP.getUserId(source)
  if user_id then
    local data = cRP.getUserDataTable(user_id)
    if data then
      data.customization = customization
    end
  end
end

function tcRP.updateHealth(health)
  local user_id = cRP.getUserId(source)
  if user_id then
    local data = cRP.getUserDataTable(user_id)
    if data then
      data.health = health
    end
  end
end
