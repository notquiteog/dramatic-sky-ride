;(function()
-- Narrow Gold 2D height synchronizer.
--
-- The Gold player-side mount card and Randy's Gen2 voxel mount proxy can use
-- different terrain-height sources on raised geometry. Keep the existing rider
-- seat offsets untouched and only reconcile that terrain component while the
-- active Flight renderer is 2D. Stadium 3D is deliberately excluded.

local PROVIDER_ID = "STADIUM2_OVERWORLD_MODELS"
local generation = mod.exports.runtimeGeneration or {}
local state = { installs = 0, playerFrames = 0, providerFrames = 0, lastDelta = 0 }

local function isGold()
  return type(generation.isGen2) == "function" and generation.isGen2(Game) == true
end

local function renderer2D()
  local rendering = mod.exports and mod.exports.flightRendering or nil
  if rendering and type(rendering.effective) == "function" then
    local ok, value = pcall(rendering.effective)
    if ok and value ~= nil then return tostring(value):lower() == "2d" end
  end
  return true
end

local function visualAltitude()
  local altitude = tonumber(flight and flight.altitude) or 0
  local fn = mod.exports and mod.exports.flightVisualAltitude or nil
  if type(fn) == "function" then
    local ok, value = pcall(fn)
    value = ok and tonumber(value) or nil
    if value ~= nil then altitude = value end
  end
  return math.max(0, altitude)
end

local function syncGoldPlayerCard(world)
  if not (isGold() and renderer2D() and flight and flight.active
      and world and world.map and world.player) then return end
  local bridge = mod.exports and mod.exports.gen2PlayerBridge or nil
  if bridge and type(bridge.ownsPlayerSprite) == "function" then
    local ok, owns = pcall(bridge.ownsPlayerSprite)
    if not ok or owns ~= true then return end
  end
  local player = world.player
  local okGround, groundY = pcall(terrainGroundHeight,
    world.map, player.cellX, player.cellY)
  groundY = okGround and tonumber(groundY) or nil
  if groundY == nil then return end
  local lift = math.max(0, visualAltitude() - math.max(0, groundY))
  player.spriteYOffset = -math.floor(lift + 0.5)
  state.playerFrames = state.playerFrames + 1
end

local function provider()
  if type(mod.find) ~= "function" then return nil end
  local ok, handle = pcall(mod.find, mod, PROVIDER_ID)
  return ok and handle and handle.exports or nil
end

local function mountProxyPose(p)
  local e = p and p.entity or nil
  return type(e) == "table" and (
    e.dramaticSkyRideVoxelProxy == true
    or e.id == "DSR_GEN2_VOXEL_MOUNT"
    or e.name == "DSR_GEN2_VOXEL_MOUNT")
end

local function syncProviderPoses(posed)
  if not (isGold() and renderer2D() and flight and flight.active) then return end
  local world = mod.exports._mountWorld and mod.exports._mountWorld(Game) or Game.overworld
  local player = world and world.player or nil
  if not (world and world.map and player) then return end

  local mountPose, playerPose
  for _, p in ipairs(posed or {}) do
    if mountProxyPose(p) then mountPose = p
    elseif p and p.isPlayer == true then playerPose = p end
  end
  if not (mountPose and playerPose) then return end

  local okGround, legacyGround = pcall(terrainGroundHeight,
    world.map, player.cellX, player.cellY)
  legacyGround = okGround and tonumber(legacyGround) or nil
  local providerGround = tonumber(mountPose.gh)
  if legacyGround == nil or providerGround == nil then return end

  local altitude = math.max(0, tonumber(flight.altitude) or 0)
  local legacyLift = math.max(0, altitude - math.max(0, legacyGround))
  local providerLift = math.max(0, altitude - math.max(0, providerGround))
  local delta = legacyLift - providerLift

  -- posesOf() stores lift as entity.py - returnedPoseY. The legacy rider pose
  -- therefore needs the inverse of the pose-Y delta used by the player bridge.
  playerPose.lift = (tonumber(playerPose.lift) or 0) - delta
  state.lastDelta = delta
  state.providerFrames = state.providerFrames + 1
end

local function installProviderSync()
  if not isGold() then return false end
  local ex = provider()
  local stadium = ex and ex.overworld or nil
  if not (type(stadium) == "table" and type(stadium.prepare) == "function") then
    return false
  end
  local marker = stadium._dramaticSkyRide2DHeightSync
  if type(marker) == "table" and marker.owner == mod.id
      and stadium.prepare == marker.wrapper then return true end

  local raw = stadium.prepare
  local wrapper = function(posed, ...)
    syncProviderPoses(posed)
    return raw(posed, ...)
  end
  stadium.prepare = wrapper
  stadium._dramaticSkyRide2DHeightSync = { owner = mod.id, raw = raw, wrapper = wrapper }
  state.installs = state.installs + 1
  return true
end

local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousUpdate(self, dt, ...)
  if isGold() and Game.overworld == self then
    syncGoldPlayerCard(self)
    installProviderSync()
  end
  return result
end

mod.events:on("game.ready", installProviderSync)
mod.events:on("mods.loaded", installProviderSync)

mod.exports.gen2TwoDHeightSync = {
  api = 1,
  status = function()
    return {
      installs = state.installs,
      playerFrames = state.playerFrames,
      providerFrames = state.providerFrames,
      lastDelta = state.lastDelta,
    }
  end,
}

installProviderSync()
log("Gen2 2D mount/rider height synchronizer loaded")
end)();
