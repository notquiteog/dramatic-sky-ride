;(function()
-- -------------------------------------------------------------------------
-- Flat-2D building-altitude presentation.
--
-- Tall landmark/building safety floors are necessary in voxel flight because
-- the mount must physically clear authored 3D geometry. In flat 2D, exposing
-- that automatic safety climb makes the mount/rider card jump vertically over
-- a building even though the top-down map does not communicate 3D height.
--
-- Keep flight.altitude completely authoritative for gameplay, collision,
-- landing and voxel rendering. This layer changes presentation only while the
-- native flat-2D renderer is active, and only for automatic tall-building
-- safety overrides. Manual altitude changes and normal terrain safety remain
-- visible as before.
-- -------------------------------------------------------------------------
local EPSILON = 0.01
local flatBuildingVisual = {
  active = false,
  lastFloor = 0,
}

local function flat2DFlightActive()
  local flat = mod.exports and mod.exports.flatFlight or nil
  if flat and type(flat.active) == "function" then
    local ok, active = pcall(flat.active)
    if ok then return active == true end
  end
  -- Fallback for unusual load orders. Match main_30's renderer gate.
  return flight and flight.active == true
    and type(voxelLevel) == "function" and voxelLevel() <= 0
end

local function currentBuildingFloor(ow)
  if type(tallBuildingMinimum) ~= "function" then return 0 end
  local ok, value = pcall(tallBuildingMinimum, ow)
  value = ok and tonumber(value) or 0
  return math.max(0, value or 0)
end

local function logicalAltitude()
  return math.max(0, tonumber(flight and flight.altitude) or 0)
end

local function requestedAltitude()
  local requested = tonumber(flight and flight.requestedAltitude)
  if requested == nil then return logicalAltitude() end
  return math.max(0, requested)
end

local function resetBuildingVisual()
  flatBuildingVisual.active = false
  flatBuildingVisual.lastFloor = 0
end

local function flatVisualAltitude(ow)
  local logical = logicalAltitude()
  if not flat2DFlightActive() or flight.phase ~= "cruise" then
    resetBuildingVisual()
    return logical
  end

  local requested = requestedAltitude()
  local safety = math.max(0, tonumber(flight.safetyAltitude) or 0)
  local building = currentBuildingFloor(ow)

  -- tallBuildingMinimum() is one contributor to safetyMinimum(). Only hide an
  -- automatic climb when that authored building floor is actually the dominant
  -- safety requirement. Terrain/cliff compensation therefore remains exactly
  -- as it was before this compatibility layer.
  local buildingDominates = building > requested + EPSILON
    and building >= safety - EPSILON

  if buildingDominates then
    flatBuildingVisual.active = true
    flatBuildingVisual.lastFloor = building
  end

  if flatBuildingVisual.active then
    if buildingDominates then
      -- While entering/over the building, let an intentional manual climb keep
      -- its normal smooth approach. Once the requested height is reached, the
      -- extra safety-only climb is visually suppressed.
      return math.min(logical, requested)
    end

    -- If another safety source (typically terrain) now dominates, immediately
    -- hand presentation back to the normal logical altitude rather than hiding
    -- that independent rule.
    if safety > requested + EPSILON then
      resetBuildingVisual()
      return logical
    end

    -- Leaving the building: logical altitude eases back down from the voxel
    -- safety floor. Keep the 2D card at the requested height until the hidden
    -- logical descent catches up, avoiding a one-frame pop on the far edge.
    if logical > requested + EPSILON then
      return requested
    end

    resetBuildingVisual()
  end

  return logical
end

local function flatVisualOffset(ow)
  if not flat2DFlightActive() or flight.phase ~= "cruise" then return 0 end
  local logical = logicalAltitude()
  local visual = flatVisualAltitude(ow)
  return math.max(0, logical - visual)
end

-- Player:pose is the shared mount presentation source consumed by native flat
-- flight. Add back only the safety-only building elevation that the core pose
-- subtracted from screen Y. Voxel paths return an offset of zero.
local previousFlatBuildingPlayerPose = Player.pose
function Player:pose(...)
  local sprite, px, py, facing, phase, flip, hopping =
    previousFlatBuildingPlayerPose(self, ...)
  local ow = Game and Game.overworld or nil
  if ow and ow.player == self then
    local offset = flatVisualOffset(ow)
    if offset > EPSILON then py = (tonumber(py) or 0) + offset end
  end
  return sprite, px, py, facing, phase, flip, hopping
end

-- Flat 2D draws the trainer separately through riderPose(), so apply the same
-- presentation offset to keep trainer and Pokemon rigidly seated together.
local previousFlatBuildingRiderPose = riderPose
riderPose = function(entity)
  local sprite, px, py, facing, phase, flip, hopping =
    previousFlatBuildingRiderPose(entity)
  local ow = Game and Game.overworld or nil
  local offset = ow and flatVisualOffset(ow) or 0
  if offset > EPSILON then py = (tonumber(py) or 0) + offset end
  return sprite, px, py, facing, phase, flip, hopping
end

-- Ground FX is a presentation-only canvas, but its dynamic shadow is derived
-- from flight.altitude. Redraw that canvas once after the normal update using
-- the visual altitude, while restoring the authoritative logical altitude
-- immediately afterwards. Gameplay never observes the temporary value.
local previousFlatBuildingUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousFlatBuildingUpdate(self, dt, ...)
  if Game and Game.overworld == self and flat2DFlightActive()
      and flight.phase == "cruise" and type(redrawGroundFx) == "function" then
    local logical = logicalAltitude()
    local visual = flatVisualAltitude(self)
    if logical - visual > EPSILON then
      flight.altitude = visual
      local ok, err = pcall(redrawGroundFx, self)
      flight.altitude = logical
      if not ok and mod.log then
        mod.log:warn("2D building-altitude shadow refresh failed: %s", tostring(err))
      end
    end
  end
  return result
end

mod.exports.flightVisualAltitude = function()
  local ow = Game and Game.overworld or nil
  return flatVisualAltitude(ow)
end
mod.exports.flatBuildingAltitudeOverride = {
  active = function() return flatBuildingVisual.active == true end,
  buildingFloor = function() return flatBuildingVisual.lastFloor or 0 end,
}

log("flat 2D building-altitude stabilization loaded")
end)();
