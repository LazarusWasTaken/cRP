local player_called
local in_call = false

function tcRP.phoneCallWaiting(player, waiting)
  if waiting then
    player_called = player
  else
    player_called = nil
  end
end

function tcRP.phoneHangUp()
  tcRP.disconnectVoice("phone", nil)
end

-- phone channel behavior
tcRP.registerVoiceCallbacks("phone", function(player)
  print("(cRPvoice-phone) requested by "..player)
  if player == player_called then
    player_called = nil
    return true
  end
end,
function(player, is_origin)
  print("(cRPvoice-phone) connected to "..player)
  in_call = true
  tcRP.setVoiceState("phone", nil, true)
  tcRP.setVoiceState("world", nil, true)
end,
function(player)
  print("(cRPvoice-phone) disconnected from "..player)
  in_call = false
  if not tcRP.isSpeaking() then -- end world voice if not speaking
    tcRP.setVoiceState("world", nil, false)
  end
end)

AddEventHandler("cRP:NUIready", function()
  -- phone channel config
  tcRP.configureVoice("phone", cfg.phone_voice_config)
end)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
    if in_call then -- force world voice if in a phone call
      tcRP.setVoiceState("world", nil, true)
    end
  end
end)
