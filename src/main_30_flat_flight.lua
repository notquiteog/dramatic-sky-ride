;(function()
-- -------------------------------------------------------------------------
-- Native flat-2D flight renderer.
--
-- Flight state, collision, altitude and encounter logic are renderer-agnostic.
-- Player:pose() already turns the player card into the airborne mount, which is
-- also the contract consumed by voxel pipelines. In flat 2D we only need to
-- compose the cropped trainer and mount in a deterministic order: trainer
-- first, mount second. The mount body therefore hides the rider crop line and
-- reads as a seated trainer rather than two independently y-sorted entities.
-- -------------------------------------------------------------------------

local flatRider = {
  id = "sky_ride_flat_rider",
  skyRideRider = true,
  skyRideFlatRider = true,
  passable = true,
}

local function flatFlightActive(player)
  local ow = Game.overworld
  return flight.active == true
    and ow ~= nil and ow.player == player
    and voxelLevel() <= 0
end

-- The separate rider entity is required by voxel renderers, where every card
-- is captured through pose(). Flat 2D draws the same rider directly inside
-- Player:draw, so keeping that entity would draw Red twice and leave draw order
-- dependent on world y-sorting.
local nativeEnsureRiderEntity = ensureRiderEntity
ensureRiderEntity = function(ow)
  if flight.active and voxelLevel() <= 0 then
    removeRiderEntity(ow)
    return nil
  end
  return nativeEnsureRiderEntity(ow)
end

local nativePlayerDraw = Player.draw
Player.draw = function(self, camX, camY)
  if not flatFlightActive(self) then
    return nativePlayerDraw(self, camX, camY)
  end

  -- Player:pose is DSR's single source of truth for the mount sprite, lift,
  -- facing and flap phase. Calling it once keeps the flat renderer in lockstep
  -- with the voxel renderer and avoids advancing pose-side animation twice.
  local mount, px, py, facing, phase, flip = self:pose()

  if showRiderEnabled() and flight.riderSprite then
    flatRider.sprite = flight.riderSprite
    local rider, rx, ry, rfacing, rphase, rflip = riderPose(flatRider)
    if rider and rider.draw then
      rider:draw(rx, ry, camX, camY, rfacing, rphase, rflip)
    end
  end

  -- Draw the Pokemon last. main_21's Pokédex-size decorator remains on this
  -- SpriteRenderer, so flat flight automatically inherits canonical sizing and
  -- every per-species SIZE option without a second scaling implementation.
  if mount and mount.draw then
    return mount:draw(px, py, camX, camY, facing, phase, flip)
  end
end

mod.exports.flatFlight = {
  active = function()
    local ow = Game.overworld
    return ow ~= nil and flatFlightActive(ow.player)
  end,
  available = function() return true end,
}

log("native 2D flight renderer loaded")
end)()
