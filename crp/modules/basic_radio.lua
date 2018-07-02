
local lang = cRP.lang
local cfg = module("cfg/radio")

local cgroups = {}
local rusers = {}

-- build groups connect graph
for k,v in pairs(cfg.channels) do
  for _,g1 in pairs(v) do
    local group = cgroups[g1]
    if not group then
      group = {}
      cgroups[g1] = group
    end

    for _,g2 in pairs(v) do
      group[g2] = true
    end
  end
end

-- connect the user to the radio
function cRP.connectRadio(user_id)
  if not rusers[user_id] then
    local player = cRP.getUserSource(user_id)
    if player then
      -- send map of players to connect to for this radio
      local groups = cRP.getUserGroups(user_id)
      local players = {}
      for ruser,_ in pairs(rusers) do -- each radio user
        for k,v in pairs(groups) do -- each player group
          for cgroup,_ in pairs(cgroups[k] or {}) do -- each group from connect graph for this group
            if cRP.hasGroup(ruser, cgroup) then -- if in group
              local rplayer = cRP.getUserSource(ruser) 
              if rplayer then
                players[rplayer] = true
              end
            end
          end
        end
      end

      cRPclient._playAudioSource(player, cfg.on_sound, 0.5)
      cRPclient.setupRadio(player, players)
      -- wait setup and connect all radio players to this new one
      for k,v in pairs(players) do
        cRPclient._connectVoice(k, "radio", player)
      end

      rusers[user_id] = true
    end
  end
end

-- disconnect the user from the radio
function cRP.disconnectRadio(user_id)
  if rusers[user_id] then
    rusers[user_id] = nil
    local player = cRP.getUserSource(user_id)
    if player then
      cRPclient._playAudioSource(player, cfg.off_sound, 0.5)
      cRPclient._disconnectRadio(player)
    end
  end
end

-- menu
cRP.registerMenuBuilder("main", function(add, data)
  local choices = {}
  local player = data.player
  local user_id = cRP.getUserId(player)
  if user_id then
    -- check if in a radio group
    local groups = cRP.getUserGroups(user_id)
    local ok = false
    for group,_ in pairs(groups) do
      if cgroups[group] then
        ok = true
        break
      end
    end

    if ok then
      choices[lang.radio.title()] = {function() 
        if rusers[user_id] then
          cRP.disconnectRadio(user_id) 
        else
          cRP.connectRadio(user_id) 
        end
      end}
    end
  end

  add(choices)
end)

-- events

AddEventHandler("cRP:playerLeave",function(user_id, source) 
  cRP.disconnectRadio(user_id)
end)

-- disconnect radio on group changes

AddEventHandler("cRP:playerLeaveGroup", function(user_id, group, gtype) 
  cRP.disconnectRadio(user_id)
end)

AddEventHandler("cRP:playerJoinGroup", function(user_id, group, gtype) 
  cRP.disconnectRadio(user_id)
end)
