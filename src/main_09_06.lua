  flight.verticalInput = 0
  flight.hudTimer = 0
  flight.notice = nil
  flight.noticeTimer = 0
  flight.species = nil
  flight.mon = nil
  flight.sprite = nil
  flight.riderSprite = nil
  flight.riderEntity = nil
  flight.groundFxSprite = nil
  flight.groundFxEntity = nil
  flight.anim = 0
  flight.boost = 0
  flight.boostWasHeld = false
  flight.autoSafetyWasActive = false
  flight.cameraManualTimer = 0
  flight.landingX, flight.landingY, flight.landingKind = nil, nil, nil
  flight.originMap, flight.originX, flight.originY = nil, nil, nil
  flight.originSurf = false
  flight.originSurfMon = nil
  if ow and ow.refreshStandingOnWarp then ow:refreshStandingOnWarp() end
end

local function beginLanding(game, forced)
  local ow = mod.exports._mountWorld(game)
  if not (flight.active and ow and ow.player) then return false end
  local x, y = ow.player.cellX, ow.player.cellY
  local kind, _, reason = landingCellKind(ow, x, y)
  if not kind then
    if not forced then
      notifyHud(reason == "surf_required" and "SURF REQUIRED" or "CAN'T LAND HERE")
      feedback("blocked")
    end
    return false
  end
  flight.landingX, flight.landingY = x, y
  flight.landingKind = kind
