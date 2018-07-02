
-- mission system module
local lang = cRP.lang
local cfg = module("cfg/mission")

-- start a mission for a player
--- mission_data: 
---- name: Mission name
---- steps: ordered list of
----- text
----- position: {x,y,z}
----- onenter(player,area)
----- onleave(player,area) (optional)
----- blipid, blipcolor (optional)
function cRP.startMission(player, mission_data)
  local user_id = cRP.getUserId(player)
  if user_id then
    local tmpdata = cRP.getUserTmpTable(user_id)
    
    cRP.stopMission(player)
    if #mission_data.steps > 0 then
      tmpdata.mission_step = 0
      tmpdata.mission_data = mission_data
      cRPclient._setDiv(player,"mission",cfg.display_css,"")
      cRP.nextMissionStep(player) -- do first step
    end
  end
end

-- end the current player mission step
function cRP.nextMissionStep(player)
  local user_id = cRP.getUserId(player)
  if user_id then
    local tmpdata = cRP.getUserTmpTable(user_id)
    if tmpdata.mission_step then -- if in a mission
      -- increase step
      tmpdata.mission_step = tmpdata.mission_step+1
      if tmpdata.mission_step > #tmpdata.mission_data.steps then -- check mission end
        cRP.stopMission(player)
      else -- mission step
        local step = tmpdata.mission_data.steps[tmpdata.mission_step]
        local x,y,z = table.unpack(step.position)
        local blipid = 1
        local blipcolor = 5
        local onleave = function(player, area) end
        if step.blipid then blipid = step.blipid end
        if step.blipcolor then blipcolor = step.blipcolor end
        if step.onleave then onleave = step.onleave end

        -- display
        cRPclient._setDivContent(player,"mission",lang.mission.display({tmpdata.mission_data.name,tmpdata.mission_step-1,#tmpdata.mission_data.steps,step.text}))

        -- blip/route
        local id = cRPclient.setNamedBlip(player, "cRP:mission", x,y,z, blipid, blipcolor, lang.mission.blip({tmpdata.mission_data.name,tmpdata.mission_step,#tmpdata.mission_data.steps}))
        cRPclient._setBlipRoute(player,id)

        -- map trigger
        cRPclient._setNamedMarker(player,"cRP:mission", x,y,z-1,0.7,0.7,0.5,255,226,0,125,150)
        cRP.setArea(player,"cRP:mission",x,y,z,1,1.5,step.onenter,step.onleave)
      end
    end
  end
end

-- stop the player mission
function cRP.stopMission(player)
  local user_id = cRP.getUserId(player)
  if user_id then
    local tmpdata = cRP.getUserTmpTable(user_id)
    tmpdata.mission_step = nil
    tmpdata.mission_data = nil

    cRPclient._removeNamedBlip(player,"cRP:mission")
    cRPclient._removeNamedMarker(player,"cRP:mission")
    cRPclient._removeDiv(player,"mission")
    cRP.removeArea(player,"cRP:mission")
  end
end

-- check if the player has a mission
function cRP.hasMission(player)
  local user_id = cRP.getUserId(player)
  if user_id then
    local tmpdata = cRP.getUserTmpTable(user_id)
    if tmpdata.mission_step then
      return true
    end
  end

  return false
end

-- MAIN MENU
cRP.registerMenuBuilder("main", function(add, data)
  local player = data.player
  local user_id = cRP.getUserId(player)
  if user_id then
    local choices = {}

    -- build admin menu
    choices[lang.mission.cancel.title()] = {function(player,choice)
      cRP.stopMission(player)
    end}

    add(choices)
  end
end)
