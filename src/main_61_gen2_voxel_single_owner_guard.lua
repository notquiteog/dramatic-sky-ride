;(function()
-- -------------------------------------------------------------------------
-- Gen2 voxel single-owner regression guard.
--
-- main_58 establishes the invariant: one DSR mount proxy, one Gold rider.
-- main_60 later adds Randy-specific 2D sizing. Randy's billboard API only
-- receives a SpriteDef, however, and Gold's flat bridge deliberately shares the
-- mount SpriteDef with its player-side placeholder. Matching the active def
-- globally therefore makes a placeholder/ghost path look like a second mount.
--
-- Narrow that sizing hook to the immediate fallback draw of the real
-- DSR_GEN2_VOXEL_MOUNT proxy. Also suppress any same-species party/follower
-- pose which survived into Randy's base cast, so Stadium and 2D both preserve
-- the single visual owner invariant without mutating follower movement state.
-- -------------------------------------------------------------------------

local PROVIDER_ID = "STADIUM2_OVERWORLD_MODELS"
local generation = mod.exports.runtimeGeneration or {}
local state = {
  installed = false,
  contextDef = nil,
  contextSpecies = nil,
  narrowedBillboardDraws = 0,
  suppressedDuplicatePoses = 0,
  lastError = nil,
}

local function isGold()
  return type(generation.isGen2) == "function"
    and generation.isGen2(Game) == true
end

local function provider()
  if not mod.find then return nil, nil end
  local ok, handle = pcall(mod.find, mod, PROVIDER_ID)
  if not ok or not handle then return nil, nil end
  return handle, handle.exports
end

local function providerModule(ex, name)
  local lib = ex and ex.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end
  local ok, value = pcall(lib.require, name)
  return ok and type(value) == "table" and value or nil
end

local function renderer2D()
  local rendering = mod.exports and mod.exports.flightRendering or nil
  if rendering and type(rendering.effective) == "function" then
    local ok, value = pcall(rendering.effective)
    if ok then return tostring(value):lower() == "2d" end
  end
  return true
end

local function cleanSpecies(value)
  if type(value) == "table" then
    value = value.species or value.pokemonSpecies or value.stadiumSpecies
      or value.dex or value.pokemonDex
  end
  if value == nil then return nil end
  local s = tostring(value):upper():gsub("[^A-Z0-9]", "")
  return s ~= "" and s or nil
end

local function activeMountSpecies()
  local api = mod.exports and mod.exports.gen2VoxelInterop or nil
  if api and type(api.mountSpecies) == "function" then
    local ok, value = pcall(api.mountSpecies)
    local species = ok and cleanSpecies(value) or nil
    if species then return species end
  end
  if flight and flight.active then
    return cleanSpecies(flight.species or (flight.mon and flight.mon.species))
  end
  if ground and ground.active then
    return cleanSpecies(ground.species or (ground.mon and ground.mon.species))
  end
  return nil
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
  return type(entity) == "table" and (
    entity.pikachuFollower == true
    or entity.wildsFollower == true
    or entity.isPokemonFollower == true
    or entity.pokepcTrailer == true
    or entity.pokepcMon ~= nil
    or entity._wildsFollowerSpecies ~= nil
    or entity._pokepcFollowerSpecies ~= nil
    or entity.pokepcFollowerSpecies ~= nil
    or entity.followerSpecies ~= nil)
end

local function isMountProxy(entity)
  return type(entity) == "table"
    and entity.dramaticSkyRideVoxelProxy == true
    and tostring(entity.id or "") == "DSR_GEN2_VOXEL_MOUNT"
end

local function duplicateMountFollower(p)
  if not (isGold() and p and not p.isPlayer and type(p.entity) == "table") then
    return false
  end
  local entity = p.entity
  if isMountProxy(entity) or not followerLike(entity) then return false end
  local mounted = activeMountSpecies()
  return mounted ~= nil and followerSpecies(entity) == mounted
end

local function clearBillboardContext()
  state.contextDef = nil
  state.contextSpecies = nil
end

local function install()
  if not isGold() then return false end
  local _, ex = provider()
  local stadium = ex and ex.overworld or nil
  local billboards = providerModule(ex, "SpriteBillboards")
  if not (type(stadium) == "table" and type(stadium.safeDraw) == "function"
          and type(stadium.prepare) == "function" and type(billboards) == "table") then
    return false
  end

  local sizeMarker = billboards._dramaticSkyRide2DSizeHook
  if not (type(sizeMarker) == "table" and sizeMarker.owner == mod.id
          and type(sizeMarker.rawMesh) == "function"
          and type(sizeMarker.meshWrapper) == "function") then
    return false
  end

  if type(billboards._dramaticSkyRideSingleOwnerGuard) == "table"
     and billboards._dramaticSkyRideSingleOwnerGuard.owner == mod.id then
    state.installed = true
    return true
  end

  -- Keep a reference to main_60's scale-aware implementation, but do not leave
  -- it installed globally. It is invoked only after safeDraw identified the
  -- real DSR proxy as the pose currently falling back to a 2D billboard.
  local scaledMesh = sizeMarker.meshWrapper
  local rawMesh = sizeMarker.rawMesh
  local rawShadow = sizeMarker.rawShadow

  local narrowMesh = function(def, frame)
    if state.contextDef ~= nil and def == state.contextDef then
      state.narrowedBillboardDraws = state.narrowedBillboardDraws + 1
      clearBillboardContext()
      return scaledMesh(def, frame)
    end
    return rawMesh(def, frame)
  end

  -- The old global shadow hook is intentionally removed. It cannot identify
  -- which entity owns a shared SpriteDef and was able to turn player/ghost
  -- placeholder passes into a second Ho-Oh. Randy's original shadow card is a
  -- safer fallback; visible mount sizing remains exact in the solid pass.
  local narrowShadow = function(def, frame)
    return rawShadow(def, frame)
  end

  billboards.mesh = narrowMesh
  billboards.shadowQuad = narrowShadow
  -- main_60 revalidates its marker every Gold update. Point that marker at the
  -- narrowed wrappers so it recognizes the hook as installed and does not
  -- wrap the shared SpriteDef globally again on the next frame.
  sizeMarker.meshWrapper = narrowMesh
  sizeMarker.shadowWrapper = narrowShadow
  sizeMarker.singleOwnerNarrowed = true

  local rawSafeDraw = stadium.safeDraw
  local safeDrawWrapper = function(p, ...)
    clearBillboardContext()

    -- A same-species party/follower body is never the active mount renderer.
    -- Returning true here means "handled": VoxelScene will not draw its 2D
    -- fallback. prepareWrapper below also prevents a Stadium body being built.
    if duplicateMountFollower(p) then
      state.suppressedDuplicatePoses = state.suppressedDuplicatePoses + 1
      return true
    end

    if renderer2D() and p and isMountProxy(p.entity) and p.sprite then
      state.contextDef = p.sprite.def
      state.contextSpecies = cleanSpecies(p.entity.dramaticSkyRideMountSpecies
        or p.entity.skyRideMountSpecies or p.entity._stadiumSkyRideSpecies)
    end

    local ok, result = pcall(rawSafeDraw, p, ...)
    if not ok then
      clearBillboardContext()
      state.lastError = "safeDraw: " .. tostring(result)
      return false
    end
    -- A successful Stadium draw has no billboard fallback to consume context.
    if result == true then clearBillboardContext() end
    return result == true
  end

  stadium.safeDraw = safeDrawWrapper
  stadium._dramaticSkyRideSingleOwnerSafeDraw = {
    owner = mod.id, raw = rawSafeDraw, wrapper = safeDrawWrapper,
  }

  -- Prevent duplicate follower Stadium models from being prepared at all.
  -- Temporarily apply Randy's documented explicit opt-out flags only while its
  -- prepare() resolves this frame, then restore the entity verbatim.
  local rawPrepare = stadium.prepare
  local prepareWrapper = function(posed, ...)
    local restore = {}
    for _, p in ipairs(posed or {}) do
      if duplicateMountFollower(p) then
        local e = p.entity
        restore[#restore + 1] = {
          entity = e,
          stadiumModel = e.stadiumModel,
          pokemonModel = e.pokemonModel,
        }
        e.stadiumModel = false
        e.pokemonModel = false
      end
    end

    local ok, result = pcall(rawPrepare, posed, ...)
    for _, item in ipairs(restore) do
      item.entity.stadiumModel = item.stadiumModel
      item.entity.pokemonModel = item.pokemonModel
    end
    if not ok then
      state.lastError = "prepare: " .. tostring(result)
      return false
    end
    return result ~= false
  end

  stadium.prepare = prepareWrapper
  stadium._dramaticSkyRideSingleOwnerPrepare = {
    owner = mod.id, raw = rawPrepare, wrapper = prepareWrapper,
  }

  billboards._dramaticSkyRideSingleOwnerGuard = {
    owner = mod.id,
    rawMesh = rawMesh,
    scaledMesh = scaledMesh,
    meshWrapper = narrowMesh,
    shadowWrapper = narrowShadow,
  }
  state.installed = true
  return true
end

local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousUpdate(self, dt, ...)
  if isGold() and Game.overworld == self then install() end
  return result
end

mod.events:on("game.ready", install)
mod.events:on("mods.loaded", install)
mod.events:on("mod.options_changed", function()
  clearBillboardContext()
  install()
end)

mod.exports.gen2VoxelSingleOwnerGuard = {
  api = 1,
  installed = function() return state.installed end,
  narrowedBillboardDraws = function() return state.narrowedBillboardDraws end,
  suppressedDuplicatePoses = function() return state.suppressedDuplicatePoses end,
  status = function()
    return {
      installed = state.installed,
      narrowedBillboardDraws = state.narrowedBillboardDraws,
      suppressedDuplicatePoses = state.suppressedDuplicatePoses,
      contextSpecies = state.contextSpecies,
      lastError = state.lastError,
    }
  end,
}

install()
log("Gen2 voxel single-owner guard loaded (proxy-only 2D sizing; duplicate mount markers suppressed)")
end)();
