    if flight.phase == "takeoff" then
      flight.targetAltitude = effectiveAltitudeTarget(self)
      flight.altitude = approachDt(flight.altitude, flight.targetAltitude,
        TAKEOFF_RATE, OBSTACLE_DESCEND_RATE, frameDt)
      if flight.altitude >= flight.targetAltitude then flight.phase = "cruise" end
    elseif flight.phase == "cruise" then
      updateRequestedAltitude(frameDt)
      -- The requested altitude is the player's choice. The effective target
      -- may temporarily be higher when a low flight crosses a cliff/roof or
      -- one of the authored landmark-building safety zones.
      flight.targetAltitude = effectiveAltitudeTarget(self)
      local autoRaised = flight.safetyAltitude
        > (flight.requestedAltitude or CRUISE_HEIGHT) + 0.01
      if autoRaised and not flight.autoSafetyWasActive then feedback("safety") end
      flight.autoSafetyWasActive = autoRaised
      local upRate = autoRaised and OBSTACLE_CLIMB_RATE or MANUAL_FOLLOW_RATE
      local downRate = (flight.verticalInput or 0) < 0
        and MANUAL_FOLLOW_RATE or OBSTACLE_DESCEND_RATE
      flight.altitude = approachDt(flight.altitude, flight.targetAltitude,
