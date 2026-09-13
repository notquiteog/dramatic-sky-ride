  pendingFollowerRestore = nil
  flight.active = true
  flight.phase = "takeoff"
  flight.altitude = terrainGroundHeight(ow.map, ow.player.cellX, ow.player.cellY)
  flight.requestedAltitude = CRUISE_HEIGHT
  flight.safetyAltitude = safetyMinimum(ow)
  flight.targetAltitude = effectiveAltitudeTarget(ow)
  flight.verticalInput = 0
  flight.hudTimer = ALTITUDE_HUD_SECONDS
  flight.notice = nil
  flight.noticeTimer = 0
  flight.species = species
  flight.mon = mon
  flight.sprite = sprite
  local riderSprite, riderReason = buildRiderSprite(ow.player)
  if not riderSprite then
    mod.log:warn("unable to build rider sprite: %s", tostring(riderReason))
  end
  flight.riderSprite = riderSprite
  flight.riderEntity = nil
  flight.groundFxSprite = nil
  flight.groundFxEntity = nil
  flight.anim = 0
  flight.boost = 0
  flight.boostWasHeld = false
  flight.autoSafetyWasActive = false
  flight.cameraManualTimer = 0
  flight.originMap = ow.map.id
  flight.originX, flight.originY = ow.player.cellX, ow.player.cellY
  flight.originSurf = wasSurfing
  flight.originSurfMon = wasSurfing and partyMonKnowsMove(game, "SURF") or nil
  flight.suspended = suspendFollowers(ow)
  installDramaticHooks()
