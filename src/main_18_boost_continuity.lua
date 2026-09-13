
;(function()

-- Seam momentum continuity ---------------------------------------------------
-- Gen1Recomp re-roots the overworld at a route/city connection. setMap()
-- clears the current move, then crossConnection starts one scripted grid
-- step into the destination map. In 1ST/3RD, Dramatic Shape's FreeMove has
-- no grid stepFramesCur to carry across, so that connector step can fall
-- back to walking speed even while the boost value itself remains full.
--
-- Keep both the boost state AND the equivalent connector-step duration until
-- real movement has resumed on the destination map. This is intentionally
-- limited to seamless connections; warps and other transitions keep their
-- normal mount-ending behaviour.
local seamMomentum = {
  active = false,
  mode = nil,
  targetMap = nil,
  frames = 0,
  movingFrames = 0,
  stepFrames = nil,
  flightBoost = 0,
  groundBlend = 0,
  groundStamina = 1,
}

local SEAM_MAX_FRAMES = 180
local SEAM_RELEASE_MOVING_FRAMES = 3

local function seamSpeedMultiplier(key)
  local percent = tonumber(optionValue(key, 100)) or 100
  percent = math.max(50, math.min(200, percent))
  return percent / 100
end

local function boostDown()
  local input = Game and Game.input
  if not (input and input.isDown) then return false end
  local ok, held = pcall(input.isDown, input, "b")
  return ok and held == true
end

local function flightConnectorFrames(p)
  local boost = flight and tonumber(flight.boost) or 0
  local multiplier = seamSpeedMultiplier("flight_speed")
    * (1 + (BOOST_MAX_MULTIPLIER - 1) * boost)
  local base = tonumber(p and p.stepFrames) or 16
  -- Match the existing non-FreeMove flight hook's lower bound. In FreeMove
  -- this is still close to the continuous pixels-per-frame equivalent and,
  -- crucially, never drops to the unboosted 16-frame fallback.
  return math.max(4, math.floor(base / math.max(0.01, multiplier)))
end

local SEAM_GROUND_SPEED = {
  ARCANINE = { base = 1.12, gallop = 1.34 },
  RAPIDASH = { base = 1.10, gallop = 1.42 },
  DODRIO = { base = 1.13, gallop = 1.31 },
  RHYHORN = { base = 0.91, gallop = 1.18 },
  RHYDON = { base = 0.89, gallop = 1.16 },
  KANGASKHAN = { base = 0.99, gallop = 1.23 },
  TAUROS = { base = 1.06, gallop = 1.39 },
  SNORLAX = { base = 0.45, gallop = 1.08 },
}

local function groundConnectorFrames(p)
  local profile = SEAM_GROUND_SPEED[ground and ground.species]
    or SEAM_GROUND_SPEED.TAUROS
  local blend = ground and tonumber(ground.speedBlend) or 0
  local multiplier = seamSpeedMultiplier("ground_speed") * profile.base
    * (1 + (profile.gallop - 1) * blend)
  -- Ground Ride's alpha.14 hook first changes the ordinary 16-frame walk
  -- into bicycle-class 8-frame movement; the profile hook then divides by
  -- the species/gallop multiplier and floors in Player:tryMove.
  local base = (tonumber(p and p.stepFrames) or 16) / 2
  return math.max(3, math.floor(base / math.max(0.01, multiplier)))
end

local function beginSeamMomentum(self, mapId, opts)
  if not (type(opts) == "table" and opts.seamless == true) then return end
  local p = self and self.player
  if flight and flight.active then
    local amount = tonumber(flight.boost) or 0
    if amount > 0.01 or flight.boostWasHeld or boostDown()
       or math.abs(seamSpeedMultiplier("flight_speed") - 1) > 0.001 then
      seamMomentum.active = true
      seamMomentum.mode = "flight"
      seamMomentum.targetMap = mapId
      seamMomentum.frames = 0
      seamMomentum.movingFrames = 0
      seamMomentum.stepFrames = flightConnectorFrames(p)
      seamMomentum.flightBoost = amount
      seamMomentum.groundBlend = 0
    end
  elseif ground and ground.active then
    local amount = tonumber(ground.speedBlend) or 0
    if amount > 0.01 or ground.gallop or boostDown()
       or math.abs(seamSpeedMultiplier("ground_speed") - 1) > 0.001 then
      seamMomentum.active = true
      seamMomentum.mode = "ground"
      seamMomentum.targetMap = mapId
      seamMomentum.frames = 0
      seamMomentum.movingFrames = 0
      seamMomentum.stepFrames = groundConnectorFrames(p)
      seamMomentum.groundBlend = amount
      seamMomentum.groundStamina = tonumber(ground.stamina) or 1
      seamMomentum.flightBoost = 0
    end
  end
end

local function applySeamMomentum(self)
  if not seamMomentum.active then return end
  local p = self and self.player
  if p and seamMomentum.stepFrames then
    -- crossConnection starts its scripted step immediately after setMap()
    -- returns, so this value is installed in time for Player:update to use it.
    p.stepFramesCur = seamMomentum.stepFrames
  end
  if seamMomentum.mode == "flight" and flight and flight.active then
    flight.boost = math.max(tonumber(flight.boost) or 0,
                            seamMomentum.flightBoost or 0)
    flight.boostWasHeld = true
  elseif seamMomentum.mode == "ground" and ground and ground.active then
    ground.speedBlend = math.max(tonumber(ground.speedBlend) or 0,
                                 seamMomentum.groundBlend or 0)
    ground.gallop = (ground.speedBlend or 0) > 0.15
    -- Loading a neighboring map must not consume or regenerate stamina.
    ground.stamina = seamMomentum.groundStamina
  else
    seamMomentum.active = false
  end
end

local seamSetMap = OverworldState.setMap
function OverworldState:setMap(mapId, x, y, facing, opts, ...)
  beginSeamMomentum(self, mapId, opts)
  local result = seamSetMap(self, mapId, x, y, facing, opts, ...)
  applySeamMomentum(self)
  return result
end

local seamUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local p = self.player
  local beforePx, beforePy = p and p.px, p and p.py
  local input = Game and Game.input
  local originalIsDown = input and input.isDown

  -- Input can be masked while the map is being re-rooted. Keep the already
  -- held boost logically down only until movement genuinely resumes.
  if seamMomentum.active and originalIsDown then
    input.isDown = function(obj, key, ...)
      if key == "b" then return true end
      return originalIsDown(obj, key, ...)
    end
  end

  applySeamMomentum(self)
  local ok, result = pcall(seamUpdate, self, dt, ...)
  if seamMomentum.active and originalIsDown then input.isDown = originalIsDown end
  if not ok then error(result, 0) end
  applySeamMomentum(self)

  if seamMomentum.active then
    seamMomentum.frames = seamMomentum.frames + 1
    p = self.player
    local onTarget = self.map and self.map.id == seamMomentum.targetMap
    local dx = p and beforePx and ((p.px or beforePx) - beforePx) or 0
    local dy = p and beforePy and ((p.py or beforePy) - beforePy) or 0
    local movedPixels = math.abs(dx) + math.abs(dy) > 0.001
    local moving = onTarget and p
      and not self.transitioning
      and (p.moving or p.stepLanded or movedPixels)

    if moving then
      seamMomentum.movingFrames = seamMomentum.movingFrames + 1
    else
      seamMomentum.movingFrames = 0
    end

    if seamMomentum.movingFrames >= SEAM_RELEASE_MOVING_FRAMES
       or seamMomentum.frames >= SEAM_MAX_FRAMES then
      seamMomentum.active = false
      seamMomentum.mode = nil
      seamMomentum.targetMap = nil
      seamMomentum.stepFrames = nil
    end
  end

  return result
end

log("alpha.15 seamless boost and connector-step continuity loaded")


end)()
