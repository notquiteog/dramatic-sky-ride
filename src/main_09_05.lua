  local kind, surfMon = landingCellKind(ow, p.cellX, p.cellY)
  if kind then return p.cellX, p.cellY, kind, surfMon end
  for radius = 1, LANDING_RADIUS do
    for dy = -radius, radius do
      for dx = -radius, radius do
        if math.max(math.abs(dx), math.abs(dy)) == radius then
          local x, y = p.cellX + dx, p.cellY + dy
          kind, surfMon = landingCellKind(ow, x, y)
          if kind then return x, y, kind, surfMon end
        end
      end
    end
  end
  return nil
end

local function clearFlight(ow, landingFeedback, surfMon)
  removeRiderEntity(ow)
  removeGroundFxEntity(ow)
  local p = ow and ow.player
  if p then
    p.bumpFrames = nil
    p.moving = false
    p.targetX, p.targetY = nil, nil
    p.progress = 0
    p.px, p.py = p.cellX * 16, p.cellY * 16
    if surfMon then
      setSurfingState(ow, true, surfMon)
    elseif p.surfing then
      setSurfingState(ow, false)
    end
  end
  restoreFollowers(ow)
  if landingFeedback then feedback("landing") end
  flight.active = false
  flight.phase = "idle"
  flight.altitude = 0
  flight.requestedAltitude = CRUISE_HEIGHT
  flight.targetAltitude = CRUISE_HEIGHT
  flight.safetyAltitude = 0
