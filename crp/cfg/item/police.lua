local items = {}

local function bvest_choices(args)
  local choices = {}

  choices["Wear"] = {function(player, choice)
    local user_id = cRP.getUserId(player)
    if user_id then
      if cRP.tryGetInventoryItem(user_id, args[1], 1, true) then -- take vest
        cRPclient._setArmour(player, 100)
      end
    end
  end}

  return choices
end

items["bulletproof_vest"] = {"Bulletproof Vest", "A handy protection.", bvest_choices, 1.5}

return items
