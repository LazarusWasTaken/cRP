local rplayers = {} -- radio players that can be accepted

function tcRP.setupRadio(players)
  rplayers = players
end

function tcRP.disconnectRadio()
  rplayers = {}
  tcRP.disconnectVoice("radio", nil)
end

-- radio channel behavior
tcRP.registerVoiceCallbacks("radio", function(player)
  print("(cRPvoice-radio) requested by "..player)
  return (rplayers[player] ~= nil)
end,
function(player, is_origin)
  print("(cRPvoice-radio) connected to "..player)
end,
function(player)
  print("(cRPvoice-radio) disconnected from "..player)
end)

AddEventHandler("cRP:NUIready", function()
  -- radio channel config
  tcRP.configureVoice("radio", cfg.radio_voice_config)
end)

-- radio push-to-talk
local talking = false

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)

    local old_talking = talking
    talking = IsControlPressed(table.unpack(cfg.controls.radio))

    if old_talking ~= talking then
      tcRP.setVoiceState("world", nil, talking)
      tcRP.setVoiceState("radio", nil, talking)
    end
  end
end)
