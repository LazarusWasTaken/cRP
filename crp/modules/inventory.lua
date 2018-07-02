local lang = cRP.lang
local cfg = module("cfg/inventory")

-- this module define the player inventory (lost after respawn, as wallet)

cRP.items = {}

-- define an inventory item (call this at server start) (parametric or plain text data)
-- idname: unique item name
-- name: display name or genfunction
-- description: item description (html) or genfunction
-- choices: menudata choices (see gui api) only as genfunction or nil
-- weight: weight or genfunction
--
-- genfunction are functions returning a correct value as: function(args) return value end
-- where args is a list of {base_idname,arg,arg,arg,...}
function cRP.defInventoryItem(idname,name,description,choices,weight)
  if weight == nil then
    weight = 0
  end

  local item = {name=name,description=description,choices=choices,weight=weight}
  cRP.items[idname] = item
end

-- give action
function ch_give(idname, player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    -- get nearest player
    local nplayer = cRPclient.getNearestPlayer(player,10)
    if nplayer then
      local nuser_id = cRP.getUserId(nplayer)
      if nuser_id then
        -- prompt number
        local amount = cRP.prompt(player,lang.inventory.give.prompt({cRP.getInventoryItemAmount(user_id,idname)}),"")
        local amount = parseInt(amount)
        -- weight check
        local new_weight = cRP.getInventoryWeight(nuser_id)+cRP.getItemWeight(idname)*amount
        if new_weight <= cRP.getInventoryMaxWeight(nuser_id) then
          if cRP.tryGetInventoryItem(user_id,idname,amount,true) then
            cRP.giveInventoryItem(nuser_id,idname,amount,true)

            cRPclient._playAnim(player,true,{{"mp_common","givetake1_a",1}},false)
            cRPclient._playAnim(nplayer,true,{{"mp_common","givetake2_a",1}},false)
          else
            cRPclient._notify(player,lang.common.invalid_value())
          end
        else
          cRPclient._notify(player,lang.inventory.full())
        end
      else
        cRPclient._notify(player,lang.common.no_player_near())
      end
    else
      cRPclient._notify(player,lang.common.no_player_near())
    end
  end
end

-- trash action
function ch_trash(idname, player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    -- prompt number
    local amount = cRP.prompt(player,lang.inventory.trash.prompt({cRP.getInventoryItemAmount(user_id,idname)}),"")
    local amount = parseInt(amount)
    if cRP.tryGetInventoryItem(user_id,idname,amount,false) then
      cRPclient._notify(player,lang.inventory.trash.done({cRP.getItemName(idname),amount}))
      cRPclient._playAnim(player,true,{{"pickup_object","pickup_low",1}},false)
    else
      cRPclient._notify(player,lang.common.invalid_value())
    end
  end
end

function cRP.computeItemName(item,args)
  if type(item.name) == "string" then return item.name
  else return item.name(args) end
end

function cRP.computeItemDescription(item,args)
  if type(item.description) == "string" then return item.description
  else return item.description(args) end
end

function cRP.computeItemChoices(item,args)
  if item.choices ~= nil then
    return item.choices(args)
  else
    return {}
  end
end

function cRP.computeItemWeight(item,args)
  if type(item.weight) == "number" then return item.weight
  else return item.weight(args) end
end


function cRP.parseItem(idname)
  return splitString(idname,"|")
end

-- return name, description, weight
function cRP.getItemDefinition(idname)
  local args = cRP.parseItem(idname)
  local item = cRP.items[args[1]]
  if item then
    return cRP.computeItemName(item,args), cRP.computeItemDescription(item,args), cRP.computeItemWeight(item,args)
  end

  return nil,nil,nil
end

function cRP.getItemName(idname)
  local args = cRP.parseItem(idname)
  local item = cRP.items[args[1]]
  if item then return cRP.computeItemName(item,args) end
  return args[1]
end

function cRP.getItemDescription(idname)
  local args = cRP.parseItem(idname)
  local item = cRP.items[args[1]]
  if item then return cRP.computeItemDescription(item,args) end
  return ""
end

function cRP.getItemChoices(idname)
  local args = cRP.parseItem(idname)
  local item = cRP.items[args[1]]
  local choices = {}
  if item then
    -- compute choices
    local cchoices = cRP.computeItemChoices(item,args)
    if cchoices then -- copy computed choices
      for k,v in pairs(cchoices) do
        choices[k] = v
      end
    end

    -- add give/trash choices
    choices[lang.inventory.give.title()] = {function(player,choice) ch_give(idname, player, choice) end, lang.inventory.give.description()}
    choices[lang.inventory.trash.title()] = {function(player, choice) ch_trash(idname, player, choice) end, lang.inventory.trash.description()}
  end

  return choices
end

function cRP.getItemWeight(idname)
  local args = cRP.parseItem(idname)
  local item = cRP.items[args[1]]
  if item then return cRP.computeItemWeight(item,args) end
  return 0
end

-- compute weight of a list of items (in inventory/chest format)
function cRP.computeItemsWeight(items)
  local weight = 0

  for k,v in pairs(items) do
    local iweight = cRP.getItemWeight(k)
    weight = weight+iweight*v.amount
  end

  return weight
end

-- add item to a connected user inventory
function cRP.giveInventoryItem(user_id,idname,amount,notify)
  if notify == nil then notify = true end -- notify by default

  local data = cRP.getUserDataTable(user_id)
  if data and amount > 0 then
    local entry = data.inventory[idname]
    if entry then -- add to entry
      entry.amount = entry.amount+amount
    else -- new entry
      data.inventory[idname] = {amount=amount}
    end

    -- notify
    if notify then
      local player = cRP.getUserSource(user_id)
      if player then
        cRPclient._notify(player,lang.inventory.give.received({cRP.getItemName(idname),amount}))
      end
    end
  end
end

-- try to get item from a connected user inventory
function cRP.tryGetInventoryItem(user_id,idname,amount,notify)
  if notify == nil then notify = true end -- notify by default

  local data = cRP.getUserDataTable(user_id)
  if data and amount > 0 then
    local entry = data.inventory[idname]
    if entry and entry.amount >= amount then -- add to entry
      entry.amount = entry.amount-amount

      -- remove entry if <= 0
      if entry.amount <= 0 then
        data.inventory[idname] = nil 
      end

      -- notify
      if notify then
        local player = cRP.getUserSource(user_id)
        if player then
          cRPclient._notify(player,lang.inventory.give.given({cRP.getItemName(idname),amount}))
        end
      end

      return true
    else
      -- notify
      if notify then
        local player = cRP.getUserSource(user_id)
        if player then
          local entry_amount = 0
          if entry then entry_amount = entry.amount end
          cRPclient._notify(player,lang.inventory.missing({cRP.getItemName(idname),amount-entry_amount}))
        end
      end
    end
  end

  return false
end

-- get item amount from a connected user inventory
function cRP.getInventoryItemAmount(user_id,idname)
  local data = cRP.getUserDataTable(user_id)
  if data and data.inventory then
    local entry = data.inventory[idname]
    if entry then
      return entry.amount
    end
  end

  return 0
end

-- get connected user inventory
-- return map of full idname => amount or nil 
function cRP.getInventory(user_id)
  local data = cRP.getUserDataTable(user_id)
  if data then
    return data.inventory
  end
end

-- return user inventory total weight
function cRP.getInventoryWeight(user_id)
  local data = cRP.getUserDataTable(user_id)
  if data and data.inventory then
    return cRP.computeItemsWeight(data.inventory)
  end

  return 0
end

-- return maximum weight of the user inventory
function cRP.getInventoryMaxWeight(user_id)
  return math.floor(cRP.expToLevel(cRP.getExp(user_id, "physical", "strength")))*cfg.inventory_weight_per_strength
end

-- clear connected user inventory
function cRP.clearInventory(user_id)
  local data = cRP.getUserDataTable(user_id)
  if data then
    data.inventory = {}
  end
end

-- INVENTORY MENU

-- open player inventory
function cRP.openInventory(source)
  local user_id = cRP.getUserId(source)

  if user_id then
    local data = cRP.getUserDataTable(user_id)
    if data then
      -- build inventory menu
      local menudata = {name=lang.inventory.title(),css={top="75px",header_color="rgba(0,125,255,0.75)"}}
      -- add inventory info
      local weight = cRP.getInventoryWeight(user_id)
      local max_weight = cRP.getInventoryMaxWeight(user_id)
      local hue = math.floor(math.max(125*(1-weight/max_weight), 0))
      menudata["<div class=\"dprogressbar\" data-value=\""..string.format("%.2f",weight/max_weight).."\" data-color=\"hsl("..hue..",100%,50%)\" data-bgcolor=\"hsl("..hue..",100%,25%)\" style=\"height: 12px; border: 3px solid black;\"></div>"] = {function()end, lang.inventory.info_weight({string.format("%.2f",weight),max_weight})}
      local kitems = {}

      -- choose callback, nested menu, create the item menu
      local choose = function(player,choice)
        if string.sub(choice,1,1) ~= "@" then -- ignore info choices
        local choices = cRP.getItemChoices(kitems[choice])
          -- build item menu
          local submenudata = {name=choice,css={top="75px",header_color="rgba(0,125,255,0.75)"}}

          -- add computed choices
          for k,v in pairs(choices) do
            submenudata[k] = v
          end

          -- nest menu
          submenudata.onclose = function()
            cRP.openInventory(source) -- reopen inventory when submenu closed
          end

          -- open menu
          cRP.openMenu(source,submenudata)
        end
      end

      -- add each item to the menu
      for k,v in pairs(data.inventory) do 
        local name,description,weight = cRP.getItemDefinition(k)
        if name ~= nil then
          kitems[name] = k -- reference item by display name
          menudata[name] = {choose,lang.inventory.iteminfo({v.amount,description,string.format("%.2f",weight)})}
        end
      end

      -- open menu
      cRP.openMenu(source,menudata)
    end
  end
end

-- init inventory
AddEventHandler("cRP:playerJoin", function(user_id,source,name,last_login)
  local data = cRP.getUserDataTable(user_id)
  if not data.inventory then
    data.inventory = {}
  end
end)


-- add open inventory to main menu
local choices = {}
choices[lang.inventory.title()] = {function(player, choice) cRP.openInventory(player) end, lang.inventory.description()}

cRP.registerMenuBuilder("main", function(add, data)
  add(choices)
end)

-- CHEST SYSTEM

local chests = {}

-- build a menu from a list of items and bind a callback(idname)
local function build_itemlist_menu(name, items, cb)
  local menu = {name=name, css={top="75px",header_color="rgba(0,255,125,0.75)"}}

  local kitems = {}

  -- choice callback
  local choose = function(player,choice)
    local idname = kitems[choice]
    if idname then
      cb(idname)
    end
  end

  -- add each item to the menu
  for k,v in pairs(items) do 
    local name,description,weight = cRP.getItemDefinition(k)
    if name then
      kitems[name] = k -- reference item by display name
      menu[name] = {choose,lang.inventory.iteminfo({v.amount,description,string.format("%.2f", weight)})}
    end
  end

  return menu
end

-- open a chest by name
-- cb_close(): called when the chest is closed (optional)
-- cb_in(idname, amount): called when an item is added (optional)
-- cb_out(idname, amount): called when an item is taken (optional)
function cRP.openChest(source, name, max_weight, cb_close, cb_in, cb_out)
  local user_id = cRP.getUserId(source)
  if user_id then
    local data = cRP.getUserDataTable(user_id)
    if data.inventory then
      if not chests[name] then
        local close_count = 0 -- used to know when the chest is closed (unlocked)

        -- load chest
        local chest = {max_weight = max_weight}
        chests[name] = chest 
        local cdata = cRP.getSData("chest:"..name)
        chest.items = json.decode(cdata) or {} -- load items

        -- open menu
        local menu = {name=lang.inventory.chest.title(), css={top="75px",header_color="rgba(0,255,125,0.75)"}}
        -- take
        local cb_take = function(idname)
          local citem = chest.items[idname]
          local amount = cRP.prompt(source, lang.inventory.chest.take.prompt({citem.amount}), "")
          amount = parseInt(amount)
          if amount >= 0 and amount <= citem.amount then
            -- take item

            -- weight check
            local new_weight = cRP.getInventoryWeight(user_id)+cRP.getItemWeight(idname)*amount
            if new_weight <= cRP.getInventoryMaxWeight(user_id) then
              cRP.giveInventoryItem(user_id, idname, amount, true)
              citem.amount = citem.amount-amount

              if citem.amount <= 0 then
                chest.items[idname] = nil -- remove item entry
              end

              if cb_out then cb_out(idname,amount) end

              -- actualize by closing
              cRP.closeMenu(source)
            else
              cRPclient._notify(source,lang.inventory.full())
            end
          else
            cRPclient._notify(source,lang.common.invalid_value())
          end
        end

        local ch_take = function(player, choice)
          local submenu = build_itemlist_menu(lang.inventory.chest.take.title(), chest.items, cb_take)
          -- add weight info
          local weight = cRP.computeItemsWeight(chest.items)
          local hue = math.floor(math.max(125*(1-weight/max_weight), 0))
          submenu["<div class=\"dprogressbar\" data-value=\""..string.format("%.2f",weight/max_weight).."\" data-color=\"hsl("..hue..",100%,50%)\" data-bgcolor=\"hsl("..hue..",100%,25%)\" style=\"height: 12px; border: 3px solid black;\"></div>"] = {function()end, lang.inventory.info_weight({string.format("%.2f",weight),max_weight})}


          submenu.onclose = function()
            close_count = close_count-1
            cRP.openMenu(player, menu)
          end
          close_count = close_count+1
          cRP.openMenu(player, submenu)
        end


        -- put
        local cb_put = function(idname)
          local amount = cRP.prompt(source, lang.inventory.chest.put.prompt({cRP.getInventoryItemAmount(user_id, idname)}), "")
          amount = parseInt(amount)

          -- weight check
          local new_weight = cRP.computeItemsWeight(chest.items)+cRP.getItemWeight(idname)*amount
          if new_weight <= max_weight then
            if amount >= 0 and cRP.tryGetInventoryItem(user_id, idname, amount, true) then
              local citem = chest.items[idname]

              if citem ~= nil then
                citem.amount = citem.amount+amount
              else -- create item entry
                chest.items[idname] = {amount=amount}
              end

              -- callback
              if cb_in then cb_in(idname,amount) end

              -- actualize by closing
              cRP.closeMenu(source)
            end
          else
            cRPclient._notify(source,lang.inventory.chest.full())
          end
        end

        local ch_put = function(player, choice)
          local submenu = build_itemlist_menu(lang.inventory.chest.put.title(), data.inventory, cb_put)
          -- add weight info
          local weight = cRP.computeItemsWeight(data.inventory)
          local max_weight = cRP.getInventoryMaxWeight(user_id)
          local hue = math.floor(math.max(125*(1-weight/max_weight), 0))
          submenu["<div class=\"dprogressbar\" data-value=\""..string.format("%.2f",weight/max_weight).."\" data-color=\"hsl("..hue..",100%,50%)\" data-bgcolor=\"hsl("..hue..",100%,25%)\" style=\"height: 12px; border: 3px solid black;\"></div>"] = {function()end, lang.inventory.info_weight({string.format("%.2f",weight),max_weight})}

          submenu.onclose = function() 
            close_count = close_count-1
            cRP.openMenu(player, menu) 
          end
          close_count = close_count+1
          cRP.openMenu(player, submenu)
        end


        -- choices
        menu[lang.inventory.chest.take.title()] = {ch_take}
        menu[lang.inventory.chest.put.title()] = {ch_put}

        menu.onclose = function()
          if close_count == 0 then -- close chest
            -- save chest items
            cRP.setSData("chest:"..name, json.encode(chest.items))
            chests[name] = nil
            if cb_close then cb_close() end -- close callback
          end
        end

        -- open menu
        cRP.openMenu(source, menu)
      else
        cRPclient._notify(source,lang.inventory.chest.already_opened())
      end
    end
  end
end

-- STATIC CHESTS

local function build_client_static_chests(source)
  local user_id = cRP.getUserId(source)
  if user_id then
    for k,v in pairs(cfg.static_chests) do
      local mtype,x,y,z = table.unpack(v)
      local schest = cfg.static_chest_types[mtype]

      if schest then
        local function schest_enter(source)
          local user_id = cRP.getUserId(source)
          if user_id ~= nil and cRP.hasPermissions(user_id,schest.permissions or {}) then
            -- open chest
            cRP.openChest(source, "static:"..k, schest.weight or 0)
          end
        end

        local function schest_leave(source)
          cRP.closeMenu(source)
        end

        cRPclient._addBlip(source,x,y,z,schest.blipid,schest.blipcolor,schest.title)
        cRPclient._addMarker(source,x,y,z-1,0.7,0.7,0.5,255,226,0,125,150)

        cRP.setArea(source,"cRP:static_chest:"..k,x,y,z,1,1.5,schest_enter,schest_leave)
      end
    end
  end
end

AddEventHandler("cRP:playerSpawn",function(user_id, source, first_spawn)
  if first_spawn then
    -- load static chests
    build_client_static_chests(source)
  end
end)


