  return false
end

function OverworldState:checkLedgeHop(dir)
  local p = self.player
  if nativeCheckLedgeHop(self, dir) then
    if ground.active then
      ground.jumpPulse = 0.35
      rumble(0.14, 0.24, 0.12)
    end
    return true
  end
  if mountOption("reverse_ledge_jumps", true) ~= true then return false end
  if not (ground.active and Game.overworld == self and p and self.map) then return false end
  local opposite = { up = "down", down = "up", left = "right", right = "left" }
  local originalDir = opposite[dir]
  if not originalDir then return false end
  local fx, fy = Collision.target(p.cellX, p.cellY, dir)
  if not self.map:inBounds(fx, fy) then return false end
  local front = self.map:cellTile(fx, fy)
  local official = false
  for _, ledge in ipairs(Game.data.field.ledges or {}) do
    if (ledge.tileset or "OVERWORLD") == self.map.def.tileset
       and ledge.facing == originalDir and ledge.input == originalDir
       and ledge.ledgeTile == front then official = true break end
  end
  if not official then return false end
  local lx, ly = Collision.target(fx, fy, dir)
  if not self.map:inBounds(lx, ly) then
    local dest, ts, cx, cy = self:connectionLanding(dir)
    if not (dest and Map.defPassable(dest, ts, cx, cy, false)) then return false end
    require("src.core.Sound").play(Game.data, "Ledge")
    p.hopFrames, p.hopTotal = 32, 32
    ground.jumpPulse = 0.35
    self:scriptMove(p, dir, 1, function() self:checkEdgeExit(dir) end)
    return true
  end
  if cellHasWarp(self.map, lx, ly) then return false end
  if self.map.isWaterCell and self.map:isWaterCell(lx, ly) then return false end
  if Collision.occupied(self.entities, lx, ly, p)
     or storyOccupied(self.entities, lx, ly, p)
     or not self.map:isWalkableCell(lx, ly) then return false end
  require("src.core.Sound").play(Game.data, "Ledge")
  p.hopFrames, p.hopTotal = 32, 32
  ground.jumpPulse = 0.35
  rumble(0.14, 0.24, 0.12)
  self:scriptMove(p, dir, 2)
  return true
end

-- Ground speed is still based on the engine's normal movement path. The
-- alpha.14 hook first supplies bicycle-class speed; this later hook applies
-- small per-species differences and the stamina-driven gallop multiplier.
mod.hooks:wrap("movement.speed", function(next, frames, ctx)
  local value = next(frames, ctx)
  if not ground.active then return value end
  local profile = GROUND_PROFILES[ground.species] or GROUND_PROFILES.TAUROS
  local multiplier = mountSpeedMultiplier("ground_speed")
    * profile.base * (1 + (profile.gallop - 1) * (ground.speedBlend or 0))
  return math.max(3, (tonumber(value) or tonumber(frames) or 8) / multiplier)
end, 95)

-- Dramatic Shape's 1ST/3RD FreeMove bypasses the engine movement.speed hook
-- and uses its own WALK/BIKE world-pixels-per-frame constants. Scale those
-- for exactly one FreeMove tick so Ground Ride profiles and gallop work in
-- voxel free movement without changing flight or camera behaviour.
if dramaticFreeMove and not dramaticFreeMove.dramaticGroundRideSpeedHook then
  local groundFreeMoveTick = dramaticFreeMove.tick
  function dramaticFreeMove.tick(state)
    local oldWalk, oldBike = dramaticFreeMove.WALK, dramaticFreeMove.BIKE
    if ground.active and isFreeCamera() then
      local profile = GROUND_PROFILES[ground.species] or GROUND_PROFILES.TAUROS
      local multiplier = mountSpeedMultiplier("ground_speed") * profile.base
        * (1 + (profile.gallop - 1) * (ground.speedBlend or 0))
      local bicycleSpeed = tonumber(oldBike) or 2
      dramaticFreeMove.WALK = bicycleSpeed * multiplier
      dramaticFreeMove.BIKE = bicycleSpeed * multiplier
    end
    local ok, result = pcall(groundFreeMoveTick, state)
    dramaticFreeMove.WALK, dramaticFreeMove.BIKE = oldWalk, oldBike
    if not ok then error(result, 0) end
    return result
  end
  dramaticFreeMove.dramaticGroundRideSpeedHook = true
end

local polishUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  if ground.resumeAfterBattle and mountOption("remount_after_battle", true) ~= true then
    ground.resumeAfterBattle = nil
  end
  local p = self.player
  local beforeX, beforeY = p and p.cellX, p and p.cellY
  local beforePx, beforePy = p and p.px, p and p.py
  local beforeMapId = self.map and self.map.id
  local result = polishUpdate(self, dt, ...)
  local frameDt = tonumber(dt) or (1 / 60)
  if ground.active and Game.overworld == self and self.player then
    local profile = GROUND_PROFILES[ground.species] or GROUND_PROFILES.TAUROS
    local sameMap = beforeMapId == (self.map and self.map.id)
    local dx = sameMap and beforePx and ((self.player.px or beforePx) - beforePx) or 0
    local dy = sameMap and beforePy and ((self.player.py or beforePy) - beforePy) or 0
    local pixelDistance = math.sqrt(dx * dx + dy * dy)
    local movingNow = sameMap and not self.transitioning
      and ((self.player.moving or self.player.stepLanded) or pixelDistance > 0.001)
    ground.movingContinuous = movingNow == true
    local held = mountOption("ground_gallop", true) and Game.input
      and Game.input:isDown("b") and (ground.stamina or 0) > 0.01
      and movingNow
    local target = held and 1 or 0
    local rate = profile.accel or 2
    if (ground.speedBlend or 0) < target then
      ground.speedBlend = math.min(target, (ground.speedBlend or 0) + rate * frameDt)
    else
      ground.speedBlend = math.max(target, (ground.speedBlend or 0) - (rate + 1) * frameDt)
    end
    ground.gallop = (ground.speedBlend or 0) > 0.15
    if held then
      ground.stamina = math.max(0, (ground.stamina or 1) - profile.drain * frameDt)
      if ground.stamina <= 0 and not ground.tiredNotified then
        ground.tiredNotified = true
        groundNotice("CATCHING BREATH", 1.4)
      end
    else
      ground.stamina = math.min(1, (ground.stamina or 1) + profile.regen * frameDt)
      if ground.stamina > 0.25 then ground.tiredNotified = false end
    end
    ground.noticeTimer = math.max(0, (ground.noticeTimer or 0) - frameDt)
    if ground.noticeTimer <= 0 then ground.notice = nil end
    ground.jumpPulse = math.max(0, (ground.jumpPulse or 0) - frameDt)

    local movedCell = beforeX and (self.player.cellX ~= beforeX or self.player.cellY ~= beforeY)
    if movedCell then ground.stepCounter = (ground.stepCounter or 0) + 1 end
    if movingNow then
      ground.dustDistance = (ground.dustDistance or 0) + pixelDistance
    else
      ground.dustDistance = 0
    end
