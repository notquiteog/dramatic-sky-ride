;(function()
-- Gold-native Ground ledge and Visible Surf state bridge.
--
-- The Gen2Compat facade exposes checkLedgeHop and player.surfing to Gen 1
-- mods, but Gold's real movement loop calls World:tryLedgeJump and reads
-- World.playerState directly. Keep the mature Gen 1 rules and translate only
-- those two state-machine seams on the live Gold World instance.

local generation = mod.exports.runtimeGeneration or {}
local installedWorld = nil
local installedState = nil
local waterStateOwned = false
local waterPreviousPlayerState = nil

local function isGold()
  return type(generation.isGen2) == "function"
    and generation.isGen2(Game) == true
end

local function entityOccupies(world, x, y, except)
  for _, entity in ipairs(world and world.entities or {}) do
    if entity ~= except
       and ((entity.cellX == x and entity.cellY == y)
         or (entity.moving and entity.targetX == x and entity.targetY == y)) then
      return true
    end
  end
  return false
end

local function reverseLedgeJump(world, dir)
  if not (isGold() and ground.active and world and world.player and world.map)
      or optionValue("reverse_ledge_jumps", true) ~= true then return false end

  local okMap, Map2 = pcall(require, "src.world.gen2.Map")
  local okPermissions, Permissions = pcall(require, "src.world.gen2.Permissions")
  if not (okMap and okPermissions and Map2 and Permissions) then return false end
  local delta = Map2.DELTA and Map2.DELTA[dir]
  local opposite = { up = "down", down = "up", left = "right", right = "left" }
  if not (delta and opposite[dir]) then return false end

  local player, map = world.player, world.map
  local frontX, frontY = player.cellX + delta[1], player.cellY + delta[2]
  local landX, landY = player.cellX + delta[1] * 2,
    player.cellY + delta[2] * 2
  if not (map:inBounds(frontX, frontY) and map:inBounds(landX, landY)) then
    return false
  end

  -- Gold tags the walkable TOP of the ledge with its legal downward/sideways
  -- facing. A reverse jump therefore recognises that tag on the landing cell,
  -- on the other side of the one-cell wall, in the opposite direction.
  local facings = Permissions.ledgeFacings(map:cellCollision(landX, landY))
  if not (facings and facings[opposite[dir]]) then return false end
  if not map:isWalkable(landX, landY) then return false end
  if map.isWaterCell and map:isWaterCell(landX, landY) then return false end
  if (map.warpAt and (map:warpAt(frontX, frontY) or map:warpAt(landX, landY)))
     or entityOccupies(world, frontX, frontY, player)
     or entityOccupies(world, landX, landY, player) then return false end

  player.targetX, player.targetY = landX, landY
  player.moving, player.jumping = true, true
  player.inGrass, player.grassShake = false, nil
  player.progress = 0
  player.stepFrames = player.stepFrames or 16
  ground.jumpPulse = 0.35
  if type(world.playSfxNamed) == "function" then
    world:playSfxNamed("Sfx_JumpOverLedge")
  end
  rumble(0.14, 0.24, 0.12)
  return true
end

local function restoreGroundBridge()
  local world, state = installedWorld, installedState
  if world and state then
    if state.raw == state.absent then
      rawset(world, "tryLedgeJump", nil)
    else
      rawset(world, "tryLedgeJump", state.raw)
    end
    if rawget(world, "_dramaticSkyRideGen2GroundBridge") == state then
      rawset(world, "_dramaticSkyRideGen2GroundBridge", nil)
    end
  end
  installedWorld, installedState = nil, nil
end

local function installGroundBridge(world)
  if not (isGold() and world) then return end
  if installedWorld == world and installedState then return end
  restoreGroundBridge()
  local previous = rawget(world, "_dramaticSkyRideGen2GroundBridge")
  if previous and type(previous.restore) == "function" then pcall(previous.restore) end

  local absent = {}
  local raw = rawget(world, "tryLedgeJump")
  local native = world.tryLedgeJump
  if type(native) ~= "function" then return end
  local state = { raw = raw == nil and absent or raw, absent = absent }
  installedWorld, installedState = world, state
  rawset(world, "tryLedgeJump", function(self, dir, ...)
    if native(self, dir, ...) then return true end
    return reverseLedgeJump(self, dir)
  end)
  state.restore = function()
    if installedWorld == world and installedState == state then
      restoreGroundBridge()
    end
  end
  rawset(world, "_dramaticSkyRideGen2GroundBridge", state)
end

local function isSurfState(state)
  return state == "surf" or state == "surf_pika"
end

-- Water landing already owns the animation and Visible Surf selection. Give
-- Gold the native traversal state at the same moment, without replaying the
-- party-menu Surf script or its forced step from the shore.
local previousSetSurfingState = setSurfingState
setSurfingState = function(ow, enabled, surfMon)
  local result = previousSetSurfingState(ow, enabled, surfMon)
  if not isGold() then return result end
  local world = mod.exports._mountWorld(Game)
  local player = world and world.player
  if not (world and player and type(world.applyPlayerState) == "function") then
    return result
  end

  if enabled == true then
    if not waterStateOwned then waterPreviousPlayerState = world.playerState end
    waterStateOwned = true
    local surfState = "surf"
    local okMoves, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
    if okMoves and FieldMoves and type(FieldMoves.surfType) == "function" then
      local okState, value = pcall(FieldMoves.surfType, surfMon)
      if okState and isSurfState(value) then surfState = value end
    end
    world:applyPlayerState(surfState)
    player.surfing = true
  elseif waterStateOwned then
    if isSurfState(world.playerState) then
      world:applyPlayerState(waterPreviousPlayerState or "normal")
    end
    player.surfing = false
    waterStateOwned = false
    waterPreviousPlayerState = nil
  end
  return result
end

local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousUpdate(self, dt, ...)
  if not isGold() then
    restoreGroundBridge()
    return result
  end

  local world = mod.exports._mountWorld(Game)
  if ground.active then installGroundBridge(world) else restoreGroundBridge() end

  -- Native Surf can also start from Gold's ordinary party menu. Mirror its
  -- authoritative playerState back to the shared marker so Visible Surf is
  -- activated on the following compatibility tick and cleared on the beach.
  local player = world and world.player
  if player and not flight.active then
    local surfing = isSurfState(world.playerState)
    if player.surfing ~= surfing then player.surfing = surfing end
    if waterStateOwned and not surfing then
      waterStateOwned = false
      waterPreviousPlayerState = nil
    end
  end
  return result
end

mod.exports.gen2GroundWaterBridge = {
  groundBridgeActive = function()
    return installedWorld ~= nil and installedState ~= nil
  end,
  ownsWaterState = function() return waterStateOwned == true end,
  nativeSurfState = function()
    local world = mod.exports._mountWorld(Game)
    return world and world.playerState or nil
  end,
}

log("Gold reverse-ledge and Flight-to-Visible-Surf bridge loaded")
end)();
