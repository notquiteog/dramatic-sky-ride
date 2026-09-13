  ensureRiderEntity(ow)
  ensureGroundFxEntity(ow)
  ow.player.bumpFrames = 2
  feedback("takeoff")
  log("takeoff on %s at %s (%d,%d)", species, ow.map.id,
      ow.player.cellX, ow.player.cellY)
  return true
end

-- Reuse Dramatic Shape's existing lift contract: VoxelScene computes lift as
-- entity.py - poseY. Returning poseY above the logical ground lifts the card
-- in every voxel camera and also carries the 3RD camera, without editing the
-- Dramatic Shape mod.
local playerPose = Player.pose
function Player:pose()
  local sprite, px, py, facing, phase, flip, hopping = playerPose(self)
  local ow = Game.overworld
  if flight.active and ow and ow.player == self then
    flight.anim = (flight.anim + 1) % 32
    local wingPhase = flight.anim >= 16 and 1 or 0
    local ground = terrainGroundHeight(ow.map, self.cellX, self.cellY)
    -- VoxelScene adds local ground height after deriving lift from poseY.
    -- Subtract that same ground component here so the final world Y stays
    -- fixed. Only explicit tall-building targets alter flight.altitude.
    local lift = math.max(0, flight.altitude - ground)
    local visual = flight.sprite or sprite
    return visual, self.px,
