;(function()
-- -------------------------------------------------------------------------
-- Clean Gen2-3D-Sprites interoperability.
--
-- Rules:
--   * Randy owns the Gold voxel compositor. DSR never toggles that compositor.
--   * DSR publishes exactly one passable mount proxy into Randy's cast.
--   * Gold's real Player is the only rider actor while mounted.
--   * Ground/Surf mounts are ordinary grounded Pokemon. Only Flight uses the
--     special Sky Ride 3D anchor.
--   * DSR never participates in battle rendering here.
-- -------------------------------------------------------------------------

local PROVIDER_ID = "STADIUM2_OVERWORLD_MODELS"
local generation = mod.exports.runtimeGeneration or {}
local state = {
  bridge = nil,
  previousExtra = nil,
  extraWrapper = nil,
  installs = 0,
  proxyFrames = 0,
  riderFrames = 0,
  filteredFollowers = 0,
  modelScaleFrames = 0,
  seatScaleFrames = 0,
  lastModelScale = 1,
  lastSeatScaleDelta = 0,
  lastError = nil,
}

local proxy = {
  id = "DSR_GEN2_VOXEL_MOUNT",
  name = "DSR_GEN2_VOXEL_MOUNT",
  passable = true,
  dramaticSkyRideVoxelProxy = true,
}

local riderProxy = {
  id = "DSR_GEN2_VOXEL_RIDER",
  name = "DSR_GEN2_VOXEL_RIDER",
  passable = true,
}

local riderState = {
  player = nil,
  rawPose = nil,
  nativePose = nil,
  wrapper = nil,
  oldMarker = nil,
}

local providerHooks = {
  stadium = nil,
  skinRaw = nil,
  skinWrapper = nil,
  prepareRaw = nil,
  prepareWrapper = nil,
  mat4 = nil,
  voxelScene = nil,
}

local function isGold()
  return type(generation.isGen2) == "function"
    and generation.isGen2(Game) == true
end

local function world()
  return mod.exports._mountWorld and mod.exports._mountWorld(Game) or nil
end

local function provider()
  if not mod.find then return nil, nil, nil end
  local ok, handle = pcall(mod.find, mod, PROVIDER_ID)
  if not ok or not handle then return nil, nil, nil end
  local ex = handle.exports
  local bridge = ex and ex.voxelPipelineState or nil
  return handle, ex, type(bridge) == "table" and bridge or nil
end

local function voxelActive()
  local _, ex, bridge = provider()
  if not (ex and bridge) then return false end
  if type(bridge.status) == "function" then
    local ok, status = pcall(bridge.status)
    if ok and type(status) == "table" and status.active ~= nil then
      return status.active == true
    end
  end
  if bridge.active ~= nil then return bridge.active == true end
  if ex.voxelComposeHook ~= nil then return ex.voxelComposeHook == true end
  return ex.rendererInstalled == true
end

local function stadiumMode()
  local rendering = mod.exports and mod.exports.flightRendering or nil
  if not (rendering and type(rendering.usesGen2VoxelStadium) == "function") then
    return false
  end
  local ok, value = pcall(rendering.usesGen2VoxelStadium)
  return ok and value == true
end

local function providerFirstPerson()
  local _, ex = provider()
  if ex and type(ex.voxelCameraMode) == "function" then
    local ok, mode = pcall(ex.voxelCameraMode)
    if ok then return tostring(mode):lower() == "first" end
  end
  return isFirstPerson and isFirstPerson() or false
end

local function mountState()
  if flight and flight.active and flight.sprite then
    return "flight", flight.species or (flight.mon and flight.mon.species), flight.sprite
  end
  if ground and ground.active and ground.sprite then
    return "ground", ground.species or (ground.mon and ground.mon.species), ground.sprite
  end
  local ex = mod.exports or {}
  if type(ex.isWaterRiding) == "function" and type(ex.waterMountSpecies) == "function"
     and type(ex._waterRideVisual) == "function" then
    local okActive, active = pcall(ex.isWaterRiding)
    if okActive and active == true then
      local okSpecies, species = pcall(ex.waterMountSpecies)
      local okSprite, sprite = pcall(ex._waterRideVisual)
      if okSpecies and okSprite and species and sprite then
        return "water", species, sprite
      end
    end
  end
  return nil
end

local function providerGroundHeight(ow, player)
  if not (ow and ow.map and player) then return nil end
  local _, ex = provider()
  local lib = ex and ex.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end

  local scene = providerHooks.voxelScene
  if not scene then
    local okScene, value = pcall(lib.require, "VoxelScene")
    if okScene and type(value) == "table" then
      scene = value
      providerHooks.voxelScene = value
    end
  end
  if not (scene and type(scene.groundAt) == "function") then return nil end

  local ok, value = pcall(scene.groundAt, ow.map, player.cellX, player.cellY)
  value = ok and tonumber(value) or nil
  if value == nil then return nil end
  return math.max(0, value)
end

local function floorHeight(ow, player)
  if not (ow and ow.map and player) then return 0 end
  local providerGround = providerGroundHeight(ow, player)
  if providerGround ~= nil then return providerGround end
  local ok, value = pcall(terrainGroundHeight, ow.map, player.cellX, player.cellY)
  value = ok and tonumber(value) or nil
  return math.max(0, value or 0)
end

local function flightLift(ow, player)
  if not (flight and flight.active) then return 0 end
  return math.max(0, (tonumber(flight.altitude) or 0) - floorHeight(ow, player))
end

local function cleanSpecies(value)
  if type(value) == "table" then value = value.species end
  if value == nil then return nil end
  local s = tostring(value):upper():gsub("[^A-Z0-9]", "")
  return s ~= "" and s or nil
end

local function followerSpecies(entity)
  if type(entity) ~= "table" then return nil end
  local values = {
    entity._wildsFollowerSpecies,
    entity._pokepcFollowerSpecies,
    entity.pokepcFollowerSpecies,
    entity.followerSpecies,
    entity.pokemonSpecies,
    entity.stadiumSpecies,
    type(entity.pokepcMon) == "table" and entity.pokepcMon.species or nil,
  }
  for _, value in ipairs(values) do
    local species = cleanSpecies(value)
    if species then return species end
  end
  return nil
end

local function followerLike(entity)
  return type(entity) == "table" and entity ~= proxy and (
    entity.pikachuFollower == true
    or entity.wildsFollower == true
    or entity.isPokemonFollower == true
    or entity.pokepcTrailer == true
    or entity.pokepcMon ~= nil
    or entity._wildsFollowerSpecies ~= nil
    or entity._pokepcFollowerSpecies ~= nil
    or entity.pokepcFollowerSpecies ~= nil)
end

local function currentMountFollower(entity)
  if not followerLike(entity) then return false end
  local _, species = mountState()
  local mounted = cleanSpecies(species)
  return mounted ~= nil and followerSpecies(entity) == mounted
end

local function configureProxy(ow, kind, species, sprite)
  local player = ow and ow.player or nil
  if not (player and kind and species and sprite) then return false end
  local lift = kind == "flight" and flightLift(ow, player) or 0
  local groundY = floorHeight(ow, player)

  proxy.sprite = sprite
  proxy.spriteDef = sprite.def
  proxy.cellX, proxy.cellY = player.cellX, player.cellY
  proxy.px, proxy.py = player.px, player.py
  proxy.targetX, proxy.targetY = player.targetX, player.targetY
  proxy.facing = player.facing
  proxy.moving = player.moving
  proxy.stepFlip = player.stepFlip
  proxy.species = species
  proxy.pokemonSpecies = species
  proxy.stadiumSpecies = species
  proxy.dramaticSkyRideMountSpecies = species
  proxy.skyRideMountSpecies = species
  proxy._stadiumSkyRideSpecies = species
  proxy._stadiumSkyRideKind = kind

  proxy._stadiumSkyRideMount = kind == "flight"
  proxy._stadiumSkyRideAnchorPx = player.px
  proxy._stadiumSkyRideAnchorPy = player.py
  proxy._stadiumSkyRideAnchorFacing = player.facing
  proxy._stadiumSkyRideGround = groundY
  proxy._stadiumSkyRideLift = lift
  proxy._stadiumSkyRideAltitude = groundY + lift

  local use3D = stadiumMode()
  proxy.stadiumModel = use3D and true or false
  proxy.pokemonModel = use3D and true or false
  return true
end

function proxy:pose()
  local ow = world()
  local kind, species, sprite = mountState()
  local player = ow and ow.player or nil
  if not (player and configureProxy(ow, kind, species, sprite)) then return nil end
  local lift = kind == "flight" and flightLift(ow, player) or 0
  local phase = 0
  if kind == "flight" then
    phase = (tonumber(flight.anim) or 0) >= 16 and 1 or 0
  elseif type(player.walkPhase) == "function" then
    local ok, value = pcall(player.walkPhase, player)
    if ok then phase = value or 0 end
  end
  return sprite, player.px, player.py - lift, player.facing,
    phase, player.stepFlip == true, false
end

local function append(out, seen, entity)
  if type(entity) ~= "table" or seen[entity] then return end
  seen[entity] = true
  out[#out + 1] = entity
end

local function shouldPublish(ow)
  if not (isGold() and voxelActive() and ow and ow.player) then return false end
  local kind, species, sprite = mountState()
  return configureProxy(ow, kind, species, sprite)
end

local function installExtraProvider()
  local _, _, bridge = provider()
  if not (bridge and type(bridge.setExtraEntitiesProvider) == "function") then return false end
  local marker = bridge._dramaticSkyRideCleanVoxelProvider
  if type(marker) == "table" and marker.owner == mod.id
     and bridge.extraEntitiesProvider == marker.wrapper then
    state.bridge = bridge
    state.previousExtra = marker.previous
    state.extraWrapper = marker.wrapper
    return true
  end

  local previous = bridge.extraEntitiesProvider
  local wrapper = function(ow)
    local out, seen = {}, {}
    if type(previous) == "function" then
      local ok, extra = pcall(previous, ow)
      if ok and type(extra) == "table" then
        for _, entity in ipairs(extra) do
          if currentMountFollower(entity) then
            state.filteredFollowers = state.filteredFollowers + 1
          else
            append(out, seen, entity)
          end
        end
      elseif not ok then
        state.lastError = "extra provider: " .. tostring(extra)
      end
    end
    if shouldPublish(ow) then
      append(out, seen, proxy)
      state.proxyFrames = state.proxyFrames + 1
    end
    return out
  end

  local ok, result = pcall(bridge.setExtraEntitiesProvider, wrapper)
  if not ok or result == false then
    state.lastError = tostring(result)
    return false
  end
  bridge._dramaticSkyRideCleanVoxelProvider = {
    owner = mod.id, previous = previous, wrapper = wrapper,
  }
  state.bridge = bridge
  state.previousExtra = previous
  state.extraWrapper = wrapper
  state.installs = state.installs + 1
  return true
end

local RIDER_FOOT = {
  LUGIA = 8.0, HO_OH = 7.5, GYARADOS = 7.0, LAPRAS = 7.0,
  MANTINE = 6.5, SUICUNE = 7.0, RAIKOU = 7.0, ENTEI = 7.2,
  TYRANITAR = 8.0,
}

local function riderSeat(species)
  return RIDER_FOOT[cleanSpecies(species)] or 7.0
end

local function mountedRiderPose(kind, ow)
  local player = ow and ow.player or nil
  if not player or providerFirstPerson() then return nil end
  local sprite, px, py, facing, phase, flip, hopping

  if kind == "flight" then
    if not (showRiderEnabled() and flight.riderSprite) then return nil end
    riderProxy.sprite = flight.riderSprite
    sprite, px, py, facing, phase, flip, hopping = riderPose(riderProxy)
  elseif kind == "ground" then
    if not (ground and ground.riderSprite) then return nil end
    riderProxy.sprite = ground.riderSprite
    sprite, px, py, facing, phase, flip, hopping = groundRiderPose(riderProxy)
  elseif kind == "water" then
    local fn = mod.exports and mod.exports._waterRideRiderPose or nil
    if type(fn) ~= "function" then return nil end
    local ok
    ok, sprite, px, py, facing, phase, flip, hopping = pcall(fn, riderProxy)
    if not ok then return nil end
  end
  if not sprite then return nil end

  if stadiumMode() then
    local _, species = mountState()
    local seat = riderSeat(species)
    if kind == "flight" then
      py = player.py - flightLift(ow, player) - seat
    else
      py = player.py - seat
    end
    px = player.px
  end
  return sprite, px or player.px, py or player.py,
    facing or player.facing, phase or 0, flip == true, hopping == true
end

local function restoreRider()
  local player = riderState.player
  if player then
    if rawget(player, "pose") == riderState.wrapper then
      rawset(player, "pose", riderState.rawPose)
    end
    if rawget(player, "_dramaticSkyRideVoxelRider") == true then
      rawset(player, "_dramaticSkyRideVoxelRider", riderState.oldMarker)
    end
  end
  riderState.player = nil
  riderState.rawPose = nil
  riderState.nativePose = nil
  riderState.wrapper = nil
  riderState.oldMarker = nil
end

local function installRider(ow)
  if not shouldPublish(ow) then
    restoreRider()
    return false
  end
  local player = ow.player
  if riderState.player == player and rawget(player, "pose") == riderState.wrapper then
    return true
  end
  restoreRider()
  local native = player.pose
  if type(native) ~= "function" then return false end
  local rawPose = rawget(player, "pose")
  local wrapper = function(self)
    local live = world()
    local kind = select(1, mountState())
    if self == (live and live.player) and kind and voxelActive() then
      local sprite, px, py, facing, phase, flip, hopping = mountedRiderPose(kind, live)
      state.riderFrames = state.riderFrames + 1
      if sprite then return sprite, px, py, facing, phase, flip, hopping end
      return nil, self.px or 0, self.py or 0, self.facing or "down", 0,
        self.stepFlip == true, false
    end
    return native(self)
  end
  riderState.player = player
  riderState.rawPose = rawPose
  riderState.nativePose = native
  riderState.wrapper = wrapper
  riderState.oldMarker = rawget(player, "_dramaticSkyRideVoxelRider")
  rawset(player, "pose", wrapper)
  rawset(player, "_dramaticSkyRideVoxelRider", true)
  return true
end

local function desiredModelHeight(species)
  local scale = 1
  local fn = mod.exports and mod.exports.mountVisualScale or nil
  if type(fn) == "function" then
    local ok, value = pcall(fn, species)
    value = ok and tonumber(value) or nil
    if value and value > 0 then scale = value end
  end
  return 16 * scale
end

-- Randy's OverworldStadium places flying mounts from an upper-back/saddle
-- anchor before DSR applies its final Pokédex scale. Preserve that same saddle
-- point when the model height changes instead of adding rider trims afterwards.
local function stadiumSeatFraction(dex)
  dex = tonumber(dex)
  if dex == 6 then return 0.50 end
  if dex == 18 or dex == 22 then return 0.58 end
  if dex == 42 or dex == 142 or dex == 149 then return 0.50 end
  if dex == 144 or dex == 145 or dex == 146 then return 0.56 end
  if dex == 148 then return 0.48 end
  return 0.52
end

local function mat4(ex)
  if providerHooks.mat4 then return providerHooks.mat4 end
  local lib = ex and ex.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end
  local ok, value = pcall(lib.require, "Mat4")
  if ok and type(value) == "table" then providerHooks.mat4 = value end
  return providerHooks.mat4
end

local function installProviderHooks()
  local _, ex = provider()
  local stadium = ex and ex.overworld or nil
  if type(stadium) ~= "table" then return false end
  providerHooks.stadium = stadium

  if type(stadium.safeDrawPlayerSkin) == "function"
     and not stadium._dramaticSkyRideCleanPlayerSkinGuard then
    local raw = stadium.safeDrawPlayerSkin
    local wrapper = function(p, ...)
      local entity = p and p.entity or nil
      if type(entity) == "table" and entity._dramaticSkyRideVoxelRider == true then
        return false
      end
      return raw(p, ...)
    end
    stadium.safeDrawPlayerSkin = wrapper
    stadium._dramaticSkyRideCleanPlayerSkinGuard = { owner = mod.id, raw = raw, wrapper = wrapper }
    providerHooks.skinRaw, providerHooks.skinWrapper = raw, wrapper
  end

  if type(stadium.prepare) == "function"
     and not stadium._dramaticSkyRideCleanMountScale then
    local raw = stadium.prepare
    local wrapper = function(posed, ...)
      local result = raw(posed, ...)
      if result ~= false and stadiumMode() then
        local M = mat4(ex)
        if M and type(M.mul) == "function" and type(M.scale) == "function" then
          for _, p in ipairs(posed or {}) do
            if p and p.entity == proxy and p.stadiumMatrix and p.stadiumMon then
              local kind, species = mountState()
              local wanted = species and desiredModelHeight(species) or nil
              local current = tonumber(p.stadiumTargetHeight)
              if not current and type(p.stadiumMon.worldHeight) == "function" then
                local ok, value = pcall(p.stadiumMon.worldHeight, p.stadiumMon)
                if ok then current = tonumber(value) end
              end
              if wanted and current and current > 0 then
                local factor = math.max(0.35, math.min(4.5, wanted / current))
                local okScale, scaled = pcall(function()
                  return M.mul(p.stadiumMatrix, M.scale(factor, factor, factor))
                end)
                if okScale and scaled then
                  local seatDelta = 0
                  if kind == "flight" and type(M.translate) == "function" then
                    seatDelta = -(wanted - current) * stadiumSeatFraction(p.stadiumDex)
                    if math.abs(seatDelta) > 0.0001 then
                      local okMove, moved = pcall(function()
                        return M.mul(M.translate(0, seatDelta, 0), scaled)
                      end)
                      if okMove and moved then scaled = moved end
                    end
                    state.lastSeatScaleDelta = seatDelta
                    state.seatScaleFrames = state.seatScaleFrames + 1
                  end
                  p.stadiumMatrix = scaled
                  p.stadiumMon.model_matrix = scaled
                  p.stadiumTargetHeight = wanted
                  p.dramaticSkyRideModelScale = factor
                  p.dramaticSkyRideSeatScaleDelta = seatDelta
                  state.lastModelScale = factor
                  state.modelScaleFrames = state.modelScaleFrames + 1
                end
              end
            end
          end
        end
      end
      return result
    end
    stadium.prepare = wrapper
    stadium._dramaticSkyRideCleanMountScale = { owner = mod.id, raw = raw, wrapper = wrapper }
    providerHooks.prepareRaw, providerHooks.prepareWrapper = raw, wrapper
  end
  return true
end

local function installFollowerGate()
  local ok, Follower = pcall(require, "src.world.gen2.Follower")
  if not ok or type(Follower) ~= "table" or type(Follower.setShouldSpawn) ~= "function" then
    return false
  end
  local marker = Follower._dramaticSkyRideCleanMountGate
  if type(marker) == "table" and marker.owner == mod.id then return true end
  local previous
  local wrapper = function(game, ow)
    if mountState() then return false end
    if type(previous) == "function" then
      local okPrev, value = pcall(previous, game, ow)
      return okPrev and value == true
    end
    return false
  end
  previous = Follower.setShouldSpawn(wrapper)
  Follower._dramaticSkyRideCleanMountGate = {
    owner = mod.id, previous = previous, wrapper = wrapper,
  }
  return true
end

local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousUpdate(self, dt, ...)
  if isGold() and Game.overworld == self then
    installExtraProvider()
    installProviderHooks()
    installFollowerGate()
    installRider(self)
  else
    restoreRider()
  end
  return result
end

mod.events:on("game.ready", function()
  if isGold() then
    installExtraProvider()
    installProviderHooks()
    installFollowerGate()
  end
end)

mod.events:on("mod.options_changed", function()
  if isGold() then
    installExtraProvider()
    installProviderHooks()
  end
end)

mod.exports.gen2VoxelInterop = {
  api = 4,
  providerId = PROVIDER_ID,
  active = function() return shouldPublish(world()) end,
  mountKind = function() return select(1, mountState()) end,
  mountSpecies = function() return select(2, mountState()) end,
  rendererEffective = function()
    local r = mod.exports and mod.exports.flightRendering or nil
    if r and type(r.effective) == "function" then
      local ok, value = pcall(r.effective)
      if ok then return value end
    end
    return "2d"
  end,
  existingExtraProviderPreserved = function() return state.previousExtra ~= nil end,
  status = function()
    return {
      voxelActive = voxelActive(),
      stadiumMode = stadiumMode(),
      proxyActive = shouldPublish(world()),
      mountKind = select(1, mountState()),
      mountSpecies = select(2, mountState()),
      proxyFrames = state.proxyFrames,
      riderFrames = state.riderFrames,
      filteredFollowers = state.filteredFollowers,
      modelScaleFrames = state.modelScaleFrames,
      modelScale = state.lastModelScale,
      seatScaleFrames = state.seatScaleFrames,
      seatScaleDelta = state.lastSeatScaleDelta,
      installs = state.installs,
      lastError = state.lastError,
    }
  end,
}

installExtraProvider()
installProviderHooks()
installFollowerGate()
log("Clean Gen2 voxel interop loaded (one proxy/rider; Stadium saddle preserved during scaling)")
end)();
