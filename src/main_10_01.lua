    ow:setMap(flight.originMap, flight.originX, flight.originY,
              ow.player.facing or "down")
    transitionGuard = guarded
    x, y = flight.originX, flight.originY
    if flight.originSurf then
      kind = "water"
      -- Preserve the valid state we took off from even if SURF was removed
      -- while airborne and an emergency save/battle transition must return
      -- the player to that original water cell. Manual water landings still
      -- require a current SURF user and are rechecked at touchdown.
      surfMon = flight.originSurfMon or partyMonKnowsMove(game, "SURF") or {}
    else
      kind = "land"
    end
  end
  if not x then return false end
  local p = ow.player
  p.cellX, p.cellY = x, y
  p.px, p.py = x * 16, y * 16
  clearFlight(ow, true, kind == "water" and surfMon or nil)
  return true
end

local function startFlight(game, mon)
  local ow = mod.exports._mountWorld(game)
  if not (ow and ow.player and ow.map) then return false end
  if not mod.exports._mountFreeRoam(game, ow) then return false end
  if ow.transitioning or (ow.runner and ow.runner.isRunning and ow.runner:isRunning()) then
    say(game, "Finish the current\nevent first.")
    return false
