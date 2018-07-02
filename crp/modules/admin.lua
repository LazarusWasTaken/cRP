local htmlEntities = module("lib/htmlEntities")
local Tools = module("lib/Tools")

-- this module define some admin menu functions

local player_lists = {}

local function ch_list(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.list") then
    if player_lists[player] then -- hide
      player_lists[player] = nil
      cRPclient._removeDiv(player,{"user_list"})
    else -- show
      local content = ""
      for k,v in pairs(cRP.rusers) do
        local source = cRP.getUserSource(k)
        local identity = cRP.getUserIdentity(k)
        if source then
          content = content.."<br />"..k.." => <span class=\"pseudo\">"..cRP.getPlayerName(source).."</span> <span class=\"endpoint\">"..cRP.getPlayerEndpoint(source).."</span>"
          if identity then
            content = content.." <span class=\"name\">"..htmlEntities.encode(identity.firstname).." "..htmlEntities.encode(identity.name).."</span> <span class=\"reg\">"..identity.registration.."</span> <span class=\"phone\">"..identity.phone.."</span>"
          end
        end
      end

      player_lists[player] = true
      local css = [[
.div_user_list{ 
  margin: auto; 
  padding: 8px; 
  width: 650px; 
  margin-top: 80px; 
  background: black; 
  color: white; 
  font-weight: bold; 
  font-size: 1.1em;
} 

.div_user_list .pseudo{ 
  color: rgb(0,255,125);
}

.div_user_list .endpoint{ 
  color: rgb(255,0,0);
}

.div_user_list .name{ 
  color: #309eff;
}

.div_user_list .reg{ 
  color: rgb(0,125,255);
}
              
.div_user_list .phone{ 
  color: rgb(211, 0, 255);
}
            ]]
      cRPclient._setDiv(player, "user_list", css, content)
    end
  end
end

local function ch_whitelist(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.whitelist") then
    local id = cRP.prompt(player,"User id to whitelist: ","")
    id = parseInt(id)
    cRP.setWhitelisted(id,true)
    cRPclient._notify(player, "whitelisted user "..id)
  end
end

local function ch_unwhitelist(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.unwhitelist") then
    local id = cRP.prompt(player,"User id to un-whitelist: ","")
    id = parseInt(id)
    cRP.setWhitelisted(id,false)
    cRPclient._notify(player, "un-whitelisted user "..id)
  end
end

local function ch_addgroup(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id ~= nil and cRP.hasPermission(user_id,"player.group.add") then
    local id = cRP.prompt(player,"User id: ","") 
    id = parseInt(id)
    local group = cRP.prompt(player,"Group to add: ","")
    if group then
      cRP.addUserGroup(id,group)
      cRPclient._notify(player, group.." added to user "..id)
    end
  end
end

local function ch_removegroup(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.group.remove") then
    local id = cRP.prompt(player,"User id: ","")
    id = parseInt(id)
    local group = cRP.prompt(player,"Group to remove: ","")
    if group then
      cRP.removeUserGroup(id,group)
      cRPclient._notify(player, group.." removed from user "..id)
    end
  end
end

local function ch_kick(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.kick") then
    local id = cRP.prompt(player,"User id to kick: ","")
    id = parseInt(id)
    local reason = cRP.prompt(player,"Reason: ","")
    local source = cRP.getUserSource(id)
    if source then
      cRP.kick(source,reason)
      cRPclient._notify(player, "kicked user "..id)
    end
  end
end

local function ch_ban(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.ban") then
    local id = cRP.prompt(player,"User id to ban: ","")
    id = parseInt(id)
    local reason = cRP.prompt(player,"Reason: ","")
    local source = cRP.getUserSource(id)
    if source then
      cRP.ban(source,reason)
      cRPclient._notify(player, "banned user "..id)
    end
  end
end

local function ch_unban(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.unban") then
    local id = cRP.prompt(player,"User id to unban: ","")
    id = parseInt(id)
    cRP.setBanned(id,false)
    cRPclient._notify(player, "un-banned user "..id)
  end
end

local function ch_emote(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.custom_emote") then
    local content = cRP.prompt(player,"Animation sequence ('dict anim optional_loops' per line): ","")
    local seq = {}
    for line in string.gmatch(content,"[^\n]+") do
      local args = {}
      for arg in string.gmatch(line,"[^%s]+") do
        table.insert(args,arg)
      end

      table.insert(seq,{args[1] or "", args[2] or "", args[3] or 1})
    end

    cRPclient._playAnim(player, true,seq,false)
  end
end

local function ch_sound(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id,"player.custom_sound") then
    local content = cRP.prompt(player,"Sound 'dict name': ","")
      local args = {}
      for arg in string.gmatch(content,"[^%s]+") do
        table.insert(args,arg)
      end
      cRPclient._playSound(player, args[1] or "", args[2] or "")
  end
end

local function ch_coords(player,choice)
  local x,y,z = cRPclient.getPosition(player)
  cRP.prompt(player,"Copy the coordinates using Ctrl-A Ctrl-C",x..","..y..","..z)
end

local function ch_tptome(player,choice)
  local x,y,z = cRPclient.getPosition(player)
  local user_id = cRP.prompt(player,"User id:","")
  local tplayer = cRP.getUserSource(tonumber(user_id))
  if tplayer then
    cRPclient._teleport(tplayer,x,y,z)
  end
end

local function ch_tpto(player,choice)
  local user_id = cRP.prompt(player,"User id:","")
  local tplayer = cRP.getUserSource(tonumber(user_id))
  if tplayer then
    cRPclient._teleport(player, cRPclient.getPosition(tplayer))
  end
end

local function ch_tptocoords(player,choice)
  local fcoords = cRP.prompt(player,"Coords x,y,z:","")
  local coords = {}
  for coord in string.gmatch(fcoords or "0,0,0","[^,]+") do
    table.insert(coords,tonumber(coord))
  end

  cRPclient._teleport(player, coords[1] or 0, coords[2] or 0, coords[3] or 0)
end

local function ch_givemoney(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local amount = cRP.prompt(player,"Amount:","")
    amount = parseInt(amount)
    cRP.giveMoney(user_id, amount)
  end
end

local function ch_giveitem(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local idname = cRP.prompt(player,"Id name:","")
    idname = idname or ""
    local amount = cRP.prompt(player,"Amount:","")
    amount = parseInt(amount)
    cRP.giveInventoryItem(user_id, idname, amount,true)
  end
end

local function ch_calladmin(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local desc = cRP.prompt(player,"Describe your problem:","") or ""
    local answered = false
    local players = {}
    for k,v in pairs(cRP.rusers) do
      local player = cRP.getUserSource(tonumber(k))
      -- check user
      if cRP.hasPermission(k,"admin.tickets") and player then
        table.insert(players,player)
      end
    end

    -- send notify and alert to all listening players
    for k,v in pairs(players) do
      async(function()
        local ok = cRP.request(v,"Admin ticket (user_id = "..user_id..") take/TP to ?: "..htmlEntities.encode(desc), 60)
        if ok then -- take the call
          if not answered then
            -- answer the call
            cRPclient._notify(player,"An admin took your ticket.")
            cRPclient._teleport(v, cRPclient.getPosition(player))
            answered = true
          else
            cRPclient._notify(v,"Ticket already taken.")
          end
        end
      end)
    end
  end
end

local player_customs = {}

local function ch_display_custom(player, choice)
  local custom = cRPclient.getCustomization(player)
  if player_customs[player] then -- hide
    player_customs[player] = nil
    cRPclient._removeDiv(player,"customization")
  else -- show
    local content = ""
    for k,v in pairs(custom) do
      content = content..k.." => "..json.encode(v).."<br />" 
    end

    player_customs[player] = true
    cRPclient._setDiv(player,"customization",".div_customization{ margin: auto; padding: 8px; width: 500px; margin-top: 80px; background: black; color: white; font-weight: bold; ", content)
  end
end

local function ch_noclip(player, choice)
  cRPclient._toggleNoclip(player)
end

local function ch_audiosource(player, choice)
  local infos = splitString(cRP.prompt(player, "Audio source: name=url, omit url to delete the named source.", ""), "=")
  local name = infos[1]
  local url = infos[2]

  if name and string.len(name) > 0 then
    if url and string.len(url) > 0 then
      local x,y,z = cRPclient.getPosition(player)
      cRPclient._setAudioSource(-1,"cRP:admin:"..name,url,0.5,x,y,z,125)
    else
      cRPclient._removeAudioSource(-1,"cRP:admin:"..name)
    end
  end
end

cRP.registerMenuBuilder("main", function(add, data)
  local user_id = cRP.getUserId(data.player)
  if user_id then
    local choices = {}

    -- build admin menu
    choices["Admin"] = {function(player,choice)
      local menu  = cRP.buildMenu("admin", {player = player})
      menu.name = "Admin"
      menu.css={top="75px",header_color="rgba(200,0,0,0.75)"}
      menu.onclose = function(player) cRP.openMainMenu(player) end -- nest menu

      if cRP.hasPermission(user_id,"player.list") then
        menu["@User list"] = {ch_list,"Show/hide user list."}
      end
      if cRP.hasPermission(user_id,"player.whitelist") then
        menu["@Whitelist user"] = {ch_whitelist}
      end
      if cRP.hasPermission(user_id,"player.group.add") then
        menu["@Add group"] = {ch_addgroup}
      end
      if cRP.hasPermission(user_id,"player.group.remove") then
        menu["@Remove group"] = {ch_removegroup}
      end
      if cRP.hasPermission(user_id,"player.unwhitelist") then
        menu["@Un-whitelist user"] = {ch_unwhitelist}
      end
      if cRP.hasPermission(user_id,"player.kick") then
        menu["@Kick"] = {ch_kick}
      end
      if cRP.hasPermission(user_id,"player.ban") then
        menu["@Ban"] = {ch_ban}
      end
      if cRP.hasPermission(user_id,"player.unban") then
        menu["@Unban"] = {ch_unban}
      end
      if cRP.hasPermission(user_id,"player.noclip") then
        menu["@Noclip"] = {ch_noclip}
      end
      if cRP.hasPermission(user_id,"player.custom_emote") then
        menu["@Custom emote"] = {ch_emote}
      end
      if cRP.hasPermission(user_id,"player.custom_sound") then
        menu["@Custom sound"] = {ch_sound}
      end
      if cRP.hasPermission(user_id,"player.custom_sound") then
        menu["@Custom audiosource"] = {ch_audiosource}
      end
      if cRP.hasPermission(user_id,"player.coords") then
        menu["@Coords"] = {ch_coords}
      end
      if cRP.hasPermission(user_id,"player.tptome") then
        menu["@TpToMe"] = {ch_tptome}
      end
      if cRP.hasPermission(user_id,"player.tpto") then
        menu["@TpTo"] = {ch_tpto}
      end
      if cRP.hasPermission(user_id,"player.tpto") then
        menu["@TpToCoords"] = {ch_tptocoords}
      end
      if cRP.hasPermission(user_id,"player.givemoney") then
        menu["@Give money"] = {ch_givemoney}
      end
      if cRP.hasPermission(user_id,"player.giveitem") then
        menu["@Give item"] = {ch_giveitem}
      end
      if cRP.hasPermission(user_id,"player.display_custom") then
        menu["@Display customization"] = {ch_display_custom}
      end
      if cRP.hasPermission(user_id,"player.calladmin") then
        menu["@Call admin"] = {ch_calladmin}
      end

      cRP.openMenu(player,menu)
    end}

    add(choices)
  end
end)

-- admin god mode
function task_god()
  SetTimeout(10000, task_god)

  for k,v in pairs(cRP.getUsersByPermission("admin.god")) do
    cRP.setHunger(v, 0)
    cRP.setThirst(v, 0)

    local player = cRP.getUserSource(v)
    if player ~= nil then
      cRPclient._setHealth(player, 200)
    end
  end
end

task_god()
