        upRate, downRate, frameDt)
    elseif flight.phase == "landing" then
      local lx = flight.landingX or self.player.cellX
      local ly = flight.landingY or self.player.cellY
      local landingGround = terrainGroundHeight(self.map, lx, ly)
      flight.altitude = math.max(landingGround,
        flight.altitude - LANDING_RATE * frameDt)
      if flight.altitude <= landingGround then
        -- A moving NPC may have occupied the cell during the descent. Abort
        -- cleanly rather than placing the player inside it.
        local kind, surfMon, reason = landingCellKind(self, lx, ly)
        if not kind then
          flight.phase = "cruise"
          flight.landingX, flight.landingY, flight.landingKind = nil, nil, nil
          notifyHud(reason == "surf_required" and "SURF REQUIRED" or "CAN'T LAND HERE")
          revealAltitude()
        else
          local p = self.player
          p.cellX, p.cellY = lx, ly
          p.px, p.py = p.cellX * 16, p.cellY * 16
          log("landed at %s (%d,%d) on %s", self.map.id, p.cellX, p.cellY, kind)
          clearFlight(self, true, kind == "water" and surfMon or nil)
        end
      end
    end
  end

