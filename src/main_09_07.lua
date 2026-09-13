  flight.phase = "landing"
  flight.verticalInput = 0
  return true
end

local function forceImmediateLand(game)
  local ow = mod.exports._mountWorld(game)
  if not (flight.active and ow and ow.player) then return false end
  local x, y, kind, surfMon = findLandingCell(ow)
  if not x and flight.originMap and ow.setMap then
    -- Emergency fallback used only when the engine must save or enter a
    -- battle while the rider is over a large invalid area. Returning to the
    -- known-safe takeoff cell is preferable to serializing a blocked cell.
    local guarded = transitionGuard
    transitionGuard = true
