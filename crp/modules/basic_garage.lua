-- a basic garage implementation

-- vehicle db
cRP.prepare("cRP/vehicles_table", [[
CREATE TABLE IF NOT EXISTS cRP_user_vehicles(
  user_id INTEGER,
  vehicle VARCHAR(100),
  CONSTRAINT pk_user_vehicles PRIMARY KEY(user_id,vehicle),
  CONSTRAINT fk_user_vehicles_users FOREIGN KEY(user_id) REFERENCES cRP_users(id) ON DELETE CASCADE
);
]])

cRP.prepare("cRP/add_vehicle","INSERT IGNORE INTO cRP_user_vehicles(user_id,vehicle) VALUES(@user_id,@vehicle)")
cRP.prepare("cRP/remove_vehicle","DELETE FROM cRP_user_vehicles WHERE user_id = @user_id AND vehicle = @vehicle")
cRP.prepare("cRP/get_vehicles","SELECT vehicle FROM cRP_user_vehicles WHERE user_id = @user_id")
cRP.prepare("cRP/get_vehicle","SELECT vehicle FROM cRP_user_vehicles WHERE user_id = @user_id AND vehicle = @vehicle")

-- init
async(function()
  cRP.execute("cRP/vehicles_table")
end)

-- load config

local Tools = module("cRP","lib/Tools")
local cfg = module("cfg/garages")
local cfg_inventory = module("cfg/inventory")
local vehicle_groups = cfg.garage_types
local lang = cRP.lang

local garages = cfg.garages

-- vehicle models index
local veh_models_ids = Tools.newIDGenerator()
local veh_models = {}

-- prepare garage menus

local garage_menus = {}

for group,vehicles in pairs(vehicle_groups) do
  -- fill vehicle models index
  for veh_model,_ in pairs(vehicles) do
    if not veh_models[veh_model] then
      veh_models[veh_model] = veh_models_ids:gen()
    end
  end

  local menu = {
    name=lang.garage.title({group}),
    css={top = "75px", header_color="rgba(255,125,0,0.75)"}
  }
  garage_menus[group] = menu

  menu[lang.garage.owned.title()] = {function(player,choice)
    local user_id = cRP.getUserId(player)
    if user_id then
      -- init tmpdata for rents
      local tmpdata = cRP.getUserTmpTable(user_id)
      if not tmpdata.rent_vehicles then
        tmpdata.rent_vehicles = {}
      end


      -- build nested menu
      local kitems = {}
      local submenu = {name=lang.garage.title({lang.garage.owned.title()}), css={top="75px",header_color="rgba(255,125,0,0.75)"}}
      submenu.onclose = function()
        cRP.openMenu(player,menu)
      end

      local choose = function(player, choice)
        local vname = kitems[choice]
        if vname then
          -- spawn vehicle
          local vehicle = vehicles[vname]
          if vehicle then
            cRP.closeMenu(player)
            cRPclient._spawnGarageVehicle(player,vname)
          end
        end
      end
      
      -- get player owned vehicles
      local pvehicles = cRP.query("cRP/get_vehicles", {user_id = user_id})
      -- add rents to whitelist
      for k,v in pairs(tmpdata.rent_vehicles) do
        if v then -- check true, prevent future neolua issues
          table.insert(pvehicles,{vehicle = k})
        end
      end

      for k,v in pairs(pvehicles) do
        local vehicle = vehicles[v.vehicle]
        if vehicle then
          submenu[vehicle[1]] = {choose,vehicle[3]}
          kitems[vehicle[1]] = v.vehicle
        end
      end

      cRP.openMenu(player,submenu)
    end
  end,lang.garage.owned.description()}

  menu[lang.garage.buy.title()] = {function(player,choice)
    local user_id = cRP.getUserId(player)
    if user_id then
      -- build nested menu
      local kitems = {}
      local submenu = {name=lang.garage.title({lang.garage.buy.title()}), css={top="75px",header_color="rgba(255,125,0,0.75)"}}
      submenu.onclose = function()
        cRP.openMenu(player,menu)
      end

      local choose = function(player, choice)
        local vname = kitems[choice]
        if vname then
          -- buy vehicle
          local vehicle = vehicles[vname]
          if vehicle and cRP.tryPayment(user_id,vehicle[2]) then
            cRP.execute("cRP/add_vehicle", {user_id = user_id, vehicle = vname})

            cRPclient._notify(player,lang.money.paid({vehicle[2]}))
            cRP.closeMenu(player)
          else
            cRPclient._notify(player,lang.money.not_enough())
          end
        end
      end
      
      -- get player owned vehicles (indexed by vehicle type name in lower case)
      local _pvehicles = cRP.query("cRP/get_vehicles", {user_id = user_id})
      local pvehicles = {}
      for k,v in pairs(_pvehicles) do
        pvehicles[string.lower(v.vehicle)] = true
      end

      -- for each existing vehicle in the garage group
      for k,v in pairs(vehicles) do
        if k ~= "_config" and pvehicles[string.lower(k)] == nil then -- not already owned
          submenu[v[1]] = {choose,lang.garage.buy.info({v[2],v[3]})}
          kitems[v[1]] = k
        end
      end

      cRP.openMenu(player,submenu)
    end
  end,lang.garage.buy.description()}

  menu[lang.garage.sell.title()] = {function(player,choice)
    local user_id = cRP.getUserId(player)
    if user_id then

      -- build nested menu
      local kitems = {}
      local submenu = {name=lang.garage.title({lang.garage.sell.title()}), css={top="75px",header_color="rgba(255,125,0,0.75)"}}
      submenu.onclose = function()
        cRP.openMenu(player,menu)
      end

      local choose = function(player, choice)
        local vname = kitems[choice]
        if vname then
          -- sell vehicle
          local vehicle = vehicles[vname]
          if vehicle then
            local price = math.ceil(vehicle[2]*cfg.sell_factor)

            local rows = cRP.query("cRP/get_vehicle", {user_id = user_id, vehicle = vname})
            if #rows > 0 then -- has vehicle
              cRP.giveMoney(user_id,price)
              cRP.execute("cRP/remove_vehicle", {user_id = user_id, vehicle = vname})

              cRPclient._notify(player,lang.money.received({price}))
              cRP.closeMenu(player)
            else
              cRPclient._notify(player,lang.common.not_found())
            end
          end
        end
      end
      
      -- get player owned vehicles (indexed by vehicle type name in lower case)
      local _pvehicles = cRP.query("cRP/get_vehicles", {user_id = user_id})
      local pvehicles = {}
      for k,v in pairs(_pvehicles) do
        pvehicles[string.lower(v.vehicle)] = true
      end

      -- for each existing vehicle in the garage group
      for k,v in pairs(pvehicles) do
        local vehicle = vehicles[k]
        if vehicle then -- not already owned
          local price = math.ceil(vehicle[2]*cfg.sell_factor)
          submenu[vehicle[1]] = {choose,lang.garage.buy.info({price,vehicle[3]})}
          kitems[vehicle[1]] = k
        end
      end

      cRP.openMenu(player,submenu)
    end
  end,lang.garage.sell.description()}

  menu[lang.garage.rent.title()] = {function(player,choice)
    local user_id = cRP.getUserId(player)
    if user_id then
      -- init tmpdata for rents
      local tmpdata = cRP.getUserTmpTable(user_id)
      if tmpdata.rent_vehicles == nil then
        tmpdata.rent_vehicles = {}
      end

      -- build nested menu
      local kitems = {}
      local submenu = {name=lang.garage.title({lang.garage.rent.title()}), css={top="75px",header_color="rgba(255,125,0,0.75)"}}
      submenu.onclose = function()
        cRP.openMenu(player,menu)
      end

      local choose = function(player, choice)
        local vname = kitems[choice]
        if vname then
          -- rent vehicle
          local vehicle = vehicles[vname]
          if vehicle then
            local price = math.ceil(vehicle[2]*cfg.rent_factor)
            if cRP.tryPayment(user_id,price) then
              -- add vehicle to rent tmp data
              tmpdata.rent_vehicles[vname] = true

              cRPclient._notify(player,lang.money.paid({price}))
              cRP.closeMenu(player)
            else
              cRPclient._notify(player,lang.money.not_enough())
            end
          end
        end
      end
      
      -- get player owned vehicles (indexed by vehicle type name in lower case)
      local _pvehicles = cRP.query("cRP/get_vehicles", {user_id = user_id})
      local pvehicles = {}
      for k,v in pairs(_pvehicles) do
        pvehicles[string.lower(v.vehicle)] = true
      end

      -- add rents to blacklist
      for k,v in pairs(tmpdata.rent_vehicles) do
        pvehicles[string.lower(k)] = true
      end

      -- for each existing vehicle in the garage group
      for k,v in pairs(vehicles) do
        if k ~= "_config" and pvehicles[string.lower(k)] == nil then -- not already owned
          local price = math.ceil(v[2]*cfg.rent_factor)
          submenu[v[1]] = {choose,lang.garage.buy.info({price,v[3]})}
          kitems[v[1]] = k
        end
      end

      cRP.openMenu(player,submenu)
    end
  end,lang.garage.rent.description()}

  menu[lang.garage.store.title()] = {function(player,choice)
    local ok, name = cRPclient.getNearestOwnedVehicle(player, 15)
    if ok then
      if vehicles[name] then
        cRPclient._despawnGarageVehicle(player, name) 
      else
        cRPclient._notify(player, lang.garage.store.wrong_garage())
      end
    else
      cRPclient._notify(player, lang.garage.store.too_far())
    end
  end, lang.garage.store.description()}
end

local function build_client_garages(source)
  local user_id = cRP.getUserId(source)
  if user_id then
    for k,v in pairs(garages) do
      local gtype,x,y,z = table.unpack(v)

      local group = vehicle_groups[gtype]
      if group then
        local gcfg = group._config

        -- enter
        local garage_enter = function(player,area)
          local user_id = cRP.getUserId(source)
          if user_id and cRP.hasPermissions(user_id,gcfg.permissions or {}) then
            local menu = garage_menus[gtype]
            if menu then
              cRP.openMenu(player,menu)
            end
          end
        end

        -- leave
        local garage_leave = function(player,area)
          cRP.closeMenu(player)
        end

        cRPclient._addBlip(source,x,y,z,gcfg.blipid,gcfg.blipcolor,lang.garage.title({gtype}))
        cRPclient._addMarker(source,x,y,z-1,0.7,0.7,0.5,0,255,125,125,150)

        cRP.setArea(source,"cRP:garage"..k,x,y,z,1,1.5,garage_enter,garage_leave)
      end
    end
  end
end

AddEventHandler("cRP:playerSpawn",function(user_id,source,first_spawn)
  if first_spawn then
    build_client_garages(source)
    cRPclient._setVehicleModelsIndex(source, veh_models)
  end
end)

-- VEHICLE MENU

-- define vehicle actions
-- action => {cb(user_id,player,veh_group,veh_name),desc}
local veh_actions = {}

-- open trunk
veh_actions[lang.vehicle.trunk.title()] = {function(user_id,player,name)
  local chestname = "u"..user_id.."veh_"..string.lower(name)
  local max_weight = cfg_inventory.vehicle_chest_weights[string.lower(name)] or cfg_inventory.default_vehicle_chest_weight

  -- open chest
  cRPclient._vc_openDoor(player, name, 5)
  cRP.openChest(player, chestname, max_weight, function()
    cRPclient._vc_closeDoor(player, name, 5)
  end)
end, lang.vehicle.trunk.description()}

-- detach trailer
veh_actions[lang.vehicle.detach_trailer.title()] = {function(user_id,player,name)
  cRPclient._vc_detachTrailer(player, name)
end, lang.vehicle.detach_trailer.description()}

-- detach towtruck
veh_actions[lang.vehicle.detach_towtruck.title()] = {function(user_id,player,name)
  cRPclient._vc_detachTowTruck(player, name)
end, lang.vehicle.detach_towtruck.description()}

-- detach cargobob
veh_actions[lang.vehicle.detach_cargobob.title()] = {function(user_id,player,name)
  cRPclient._vc_detachCargobob(player, name)
end, lang.vehicle.detach_cargobob.description()}

-- lock/unlock
veh_actions[lang.vehicle.lock.title()] = {function(user_id,player,name)
  cRPclient._vc_toggleLock(player, name)
end, lang.vehicle.lock.description()}

-- engine on/off
veh_actions[lang.vehicle.engine.title()] = {function(user_id,player,name)
  cRPclient._vc_toggleEngine(player, name)
end, lang.vehicle.engine.description()}

local function ch_vehicle(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    -- check vehicle
    local ok,name = cRPclient.getNearestOwnedVehicle(player,7)
    if ok then
      -- build vehicle menu
      local menu = cRP.buildMenu("vehicle", {user_id = user_id, player = player, vname = name})
      menu.name=lang.vehicle.title()
      menu.css={top="75px",header_color="rgba(255,125,0,0.75)"}

      for k,v in pairs(veh_actions) do
        menu[k] = {function(player,choice) v[1](user_id,player,name) end, v[2]}
      end

      cRP.openMenu(player,menu)
    else
      cRPclient._notify(player,lang.vehicle.no_owned_near())
    end
  end
end

-- ask trunk (open other user car chest)
local function ch_asktrunk(player,choice)
  local nplayer = cRPclient.getNearestPlayer(player,10)
  local nuser_id = cRP.getUserId(nplayer)
  if nuser_id then
    cRPclient._notify(player,lang.vehicle.asktrunk.asked())
    if cRP.request(nplayer,lang.vehicle.asktrunk.request(),15) then -- request accepted, open trunk
      local ok,name = cRPclient.getNearestOwnedVehicle(nplayer,7)
      if ok then
        local chestname = "u"..nuser_id.."veh_"..string.lower(name)
        local max_weight = cfg_inventory.vehicle_chest_weights[string.lower(name)] or cfg_inventory.default_vehicle_chest_weight

        -- open chest
        local cb_out = function(idname,amount)
          cRPclient._notify(nplayer,lang.inventory.give.given({cRP.getItemName(idname),amount}))
        end

        local cb_in = function(idname,amount)
          cRPclient._notify(nplayer,lang.inventory.give.received({cRP.getItemName(idname),amount}))
        end

        cRPclient._vc_openDoor(nplayer, name, 5)
        cRP.openChest(player, chestname, max_weight, function()
          cRPclient._vc_closeDoor(nplayer, name, 5)
        end,cb_in,cb_out)
      else
        cRPclient._notify(player,lang.vehicle.no_owned_near())
        cRPclient._notify(nplayer,lang.vehicle.no_owned_near())
      end
    else
      cRPclient._notify(player,lang.common.request_refused())
    end
  else
    cRPclient._notify(player,lang.common.no_player_near())
  end
end

-- repair nearest vehicle
local function ch_repair(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    -- anim and repair
    if cRP.tryGetInventoryItem(user_id,"repairkit",1,true) then
      cRPclient._playAnim(player,false,{task="WORLD_HUMAN_WELDING"},false)
      SetTimeout(15000, function()
        cRPclient._fixeNearestVehicle(player,7)
        cRPclient._stopAnim(player,false)
      end)
    end
  end
end

-- replace nearest vehicle
local function ch_replace(player,choice)
  cRPclient._replaceNearestVehicle(player,7)
end

cRP.registerMenuBuilder("main", function(add, data)
  local user_id = cRP.getUserId(data.player)
  if user_id then
    -- add vehicle entry
    local choices = {}
    choices[lang.vehicle.title()] = {ch_vehicle}

    -- add ask trunk
    choices[lang.vehicle.asktrunk.title()] = {ch_asktrunk}

    -- add repair functions
    if cRP.hasPermission(user_id, "vehicle.repair") then
      choices[lang.vehicle.repair.title()] = {ch_repair, lang.vehicle.repair.description()}
    end

    if cRP.hasPermission(user_id, "vehicle.replace") then
      choices[lang.vehicle.replace.title()] = {ch_replace, lang.vehicle.replace.description()}
    end

    add(choices)
  end
end)
