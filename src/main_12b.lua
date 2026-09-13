emain airborne.")
        feedback("blocked")
      end
      out[i] = copy
      break
    end
  end
  return out
end, 90)

-- Party menu integration. Hook entries use onSelect, which Gen1Recomp calls
-- directly with the chosen mon and live game.
mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
  local out = next(game, items, mon, ctx)
  if type(out) ~= "table" then out = items end
  if flight.active then
    -- Native Gen1Recomp adds SURF to this submenu. While airborne the only
    -- legal transition to Surf is a water landing, so remove the manual row.
    for i = #out, 1, -1 do
      local item = out[i]
      if type(item) == "table" and item.action == "surf" then
        table.remove(out, i)
      end
    end
    return out
  end
  if ctx and ctx.battle then return out end
  if not mountSpecies(game, mon) then return out end

  -- Keep the command visible even when takeoff is currently impossible.
  -- startFlight then explains the exact blocker (indoors, wrong camera,
  -- fainted mount, bike/surf), which is much easier to diagnose than a row
  -- silently disappearing.
  table.insert(out, 1, {
    label = Strings("RIDE & FLY"),
    onSelect = function(selected, liveGame)
      -- Close PartyMenu before returning control to the overworld.
      mod.exports._closeMountMenus(liveGame)
      for i, partyMon in ipairs(liveGame.save.party or {}) do
        if partyMon == selected then lastMountIndex = i break end
      end
      startFlight(liveGame, selected)
    end,
  })
  return out
end, 50)

mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id) then return end
  if payload.key == "show_rider" then
    if not flight.active then return end
    if payload.value == true then
      ensureRiderEntity(Game.overworld)
    else
      removeRiderEntity(Game.overworld)
    end
    return
  end
  if payload.key == "manual_altitude" and flight.active
     and payload.value ~= true then
    flight.requestedAltitude = CRUISE_HEIGHT
    revealAltitude()
  elseif payload.key == "altitude_display" and flight.active
     and payload.value ~= "off" then
    revealAltitude()
  elseif payload.key == "vertical_speed" and flight.active then
    revealAltitude()
  elseif (payload.key == "landing_marker" or payload.key == "dynamic_shadow")
     and flight.active then
    ensureGroundFxEntity(Game.overworld)
  elseif payload.key == "flight_boost" and payload.value ~= true then
    flight.boost = 0
  end
end)

local function preferredMount(game)
  local party = game and game.save and game.save.party or {}
  if lastMountIndex and healthy(party[lastMountIndex])
     and mountSpecies(game, party[lastMountIndex]) then
    return party[lastMountIndex]
  end
  for i, mon in ipairs(party) do
    if healthy(mon) and mountSpecies(game, mon) then
      lastMountIndex = i
      return mon
    end
  end
