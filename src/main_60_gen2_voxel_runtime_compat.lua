;(function()
-- -------------------------------------------------------------------------
-- Gen2-3D-Sprites runtime compatibility fixes.
--
-- Keep this layer deliberately narrow. The known-good single mount proxy and
-- shared Flight altitude live in main_58 and are not modified here.
--
-- 1) Randy embeds visible land/water Wilds. Both its collision callback and
--    world.stepped contact path converge on SpawnLogic:_startBattle(). While
--    DSR is flying, those ground/water encounters are below the rider and must
--    not start a battle. Wild Skies is a different mod/runtime and is untouched.
-- 2) Randy owns a separate SpriteBillboards module. Its default card is always
--    16x16, bypassing DSR's Pokedex/per-species mount-size hook from main_21.
--    Rebuild only the ACTIVE DSR mount card at DSR's exact visual scale while
--    MOUNT RENDERER is 2D. Stadium geometry and every non-DSR sprite are left
--    completely unchanged.
-- -------------------------------------------------------------------------

local PROVIDER_ID = "STADIUM2_OVERWORLD_MODELS"
local generation = mod.exports.runtimeGeneration or {}
local Assets = require("src.render.Assets")

local state = {
  battleGateInstalled = false,
  blockedGroundBattles = 0,
  billboardHookInstalled = false,
  scaled2DMeshes = 0,
  nativeHgssMeshes = 0,
  last2DScale = 1,
  lastError = nil,
}

local scaledMeshes = {}

local function isGold()
  return type(generation.isGen2) == "function"
    and generation.isGen2(Game) == true
end

local function providerExports()
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, PROVIDER_ID)
  return ok and handle and handle.exports or nil
end

local function currentMount()
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

local function renderer2D()
  local rendering = mod.exports and mod.exports.flightRendering or nil
  if rendering and type(rendering.effective) == "function" then
    local ok, value = pcall(rendering.effective)
    if ok then return tostring(value):lower() == "2d" end
  end
  return true
end

local function mountScale(species)
  local fn = mod.exports and mod.exports.mountVisualScale or nil
  if type(fn) == "function" then
    local ok, value = pcall(fn, species)
    value = ok and tonumber(value) or nil
    if value and value > 0 then return value end
  end
  return 1
end

-- The canonical 16x96 Gyarados silhouette fills almost the entire square and
-- reads substantially larger than the native HGSS crop at the same Pokédex
-- scale. Reduce only that classic 2D card; native HGSS/PokeMMO keeps its exact
-- existing size.
local CLASSIC_2D_SCALE = { GYARADOS = 0.72 }
local function classic2DScale(species)
  local scale = mountScale(species)
  local key = tostring(species or ""):upper():gsub("[^A-Z0-9]", "")
  return scale * (CLASSIC_2D_SCALE[key] or 1)
end

-- -------------------------------------------------------------------------
-- Randy embedded-Wilds battle gate.
--
-- SpawnLogic:onCollision() and SpawnLogic:onStepped() both call _startBattle.
-- Hooking that single seam is important: DSR deliberately makes entity
-- collision passable during Flight, so the player can enter a roaming mon's
-- cell and onStepped would otherwise start the encounter one callback later.
-- -------------------------------------------------------------------------
local function installFlightBattleGate()
  local ex = providerExports()
  local wilds = ex and ex.wilds or nil
  local logic = wilds and wilds.logic or nil
  if not (type(logic) == "table" and type(logic._startBattle) == "function") then
    return false
  end

  local marker = logic._dramaticSkyRideFlightBattleGate
  if type(marker) == "table" and marker.owner == mod.id
     and logic._startBattle == marker.wrapper then
    state.battleGateInstalled = true
    return true
  end

  local raw = logic._startBattle
  local wrapper = function(self, record, ...)
    if isGold() and flight and flight.active == true then
      state.blockedGroundBattles = state.blockedGroundBattles + 1
      return false
    end
    return raw(self, record, ...)
  end

  logic._startBattle = wrapper
  logic._dramaticSkyRideFlightBattleGate = {
    owner = mod.id,
    raw = raw,
    wrapper = wrapper,
  }
  state.battleGateInstalled = true
  return true
end

local function providerModule(ex, name)
  local lib = ex and ex.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end
  local ok, value = pcall(lib.require, name)
  return ok and type(value) == "table" and value or nil
end

local function activeMountDef()
  local _, species, sprite = currentMount()
  return species, sprite and sprite.def or nil
end

local function clearScaledMeshes()
  for _, mesh in pairs(scaledMeshes) do
    if mesh and mesh ~= false and mesh.release then pcall(mesh.release, mesh) end
  end
  scaledMeshes = {}
end

local function nativeHgssDef(def)
  return type(def) == "table" and def.dramaticSkyRideNativePokeMMO == true
end

local function nativeRow(frame)
  frame = tonumber(frame) or 0
  if frame == 1 or frame == 4 then return 3 end
  if frame == 2 or frame == 5 then return 1 end
  return 0
end

local function nativeColumn(frame)
  if (tonumber(frame) or 0) < 3 then return 0 end
  local ow = mod.exports._mountWorld and mod.exports._mountWorld(Game) or nil
  local player = ow and ow.player or nil
  return math.floor((tonumber(player and player.animClock) or 0) / 8) % 4
end

local function buildNativeHgssCard(Voxel3D, def, frame, species)
  local correction = mod.exports and mod.exports.nativePokeMMOSizeCorrection or nil
  local crop = correction and type(correction.cropForDef) == "function"
    and correction.cropForDef(def) or nil
  if not crop then return nil end

  local correctedScale = mountScale(species)
  if correction and type(correction.scale) == "function" then
    local ok, value = pcall(correction.scale, species)
    value = ok and tonumber(value) or nil
    if value and value > 0 then correctedScale = value end
  end
  local scale = (tonumber(crop.fit) or 1) * correctedScale
  state.last2DScale = correctedScale

  local row, col = nativeRow(frame), nativeColumn(frame)
  local key = table.concat({ "hgss", tostring(def.image), tostring(frame),
    tostring(row), tostring(col), tostring(species), string.format("%.5f", scale),
    tostring(crop.left), tostring(crop.top), tostring(crop.width), tostring(crop.height) }, "#")
  if scaledMeshes[key] ~= nil then return scaledMeshes[key] or nil end

  local atlasW, atlasH = tonumber(crop.atlasW), tonumber(crop.atlasH)
  local tileW, tileH = tonumber(crop.tileW), tonumber(crop.tileH)
  local left, top = tonumber(crop.left) or 0, tonumber(crop.top) or 0
  local width, height = tonumber(crop.width), tonumber(crop.height)
  if not (atlasW and atlasH and tileW and tileH and width and height
      and atlasW > 0 and atlasH > 0 and tileW > 0 and tileH > 0) then return nil end

  local eps = 0.05
  local u0 = (col * tileW + left + eps) / atlasW
  local u1 = (col * tileW + left + width - eps) / atlasW
  local v0 = (row * tileH + top + eps) / atlasH
  local v1 = (row * tileH + top + height - eps) / atlasH
  local drawnW, drawnH = width * scale, height * scale
  local x0, x1 = 8 - drawnW / 2, 8 + drawnW / 2
  local verts = {
    { x0, 0,      0, u0, v1, 1 }, { x1, 0,      0, u1, v1, 1 },
    { x1, drawnH, 0, u1, v0, 1 }, { x0, drawnH, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  local ok, mesh = pcall(Voxel3D.newMesh, verts, indices)
  scaledMeshes[key] = ok and mesh or false
  if ok and mesh then state.nativeHgssMeshes = state.nativeHgssMeshes + 1 end
  return ok and mesh or nil
end

local function buildScaledCard(Voxel3D, def, frame, scale)
  if not (Voxel3D and type(Voxel3D.newMesh) == "function"
          and type(Voxel3D.pushQuad) == "function"
          and def and type(def.image) == "string") then
    return nil
  end
  local okImage, img = pcall(Assets.image, def.image)
  if not (okImage and img and img.getDimensions) then return nil end
  local iw, ih = img:getDimensions()
  if not (iw and ih and iw > 0 and ih > 0) then return nil end

  local fy = (tonumber(frame) or 0) * 16
  if fy + 16 > ih then fy = 0 end
  local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
  local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
  local halfW = 8 * scale
  local x0, x1 = 8 - halfW, 8 + halfW
  local y1 = 16 * scale
  local verts = {
    { x0, 0,  0, u0, v1, 1 }, { x1, 0,  0, u1, v1, 1 },
    { x1, y1, 0, u1, v0, 1 }, { x0, y1, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  local ok, mesh = pcall(Voxel3D.newMesh, verts, indices)
  return ok and mesh or nil
end

local function install2DBillboardSizeHook()
  local ex = providerExports()
  local billboards = providerModule(ex, "SpriteBillboards")
  local voxel3D = providerModule(ex, "Voxel3D")
  if not (billboards and voxel3D and type(billboards.mesh) == "function"
          and type(billboards.shadowQuad) == "function") then
    return false
  end

  local marker = billboards._dramaticSkyRide2DSizeHook
  if type(marker) == "table" and marker.owner == mod.id
     and billboards.mesh == marker.meshWrapper then
    state.billboardHookInstalled = true
    return true
  end

  local rawMesh = billboards.mesh
  local rawShadow = billboards.shadowQuad

  local function scaled(def, frame, fallback)
    if not (isGold() and renderer2D()) then return fallback(def, frame) end
    local species, activeDef = activeMountDef()
    if not (species and activeDef and def == activeDef) then
      return fallback(def, frame)
    end

    if nativeHgssDef(def) then
      return buildNativeHgssCard(voxel3D, def, frame, species) or fallback(def, frame)
    end

    local scale = classic2DScale(species)
    state.last2DScale = scale
    if math.abs(scale - 1) < 0.0001 then return fallback(def, frame) end

    local key = table.concat({
      tostring(def.image), tostring(frame), tostring(species),
      string.format("%.4f", scale),
    }, "#")
    if scaledMeshes[key] == nil then
      scaledMeshes[key] = buildScaledCard(voxel3D, def, frame, scale) or false
      if scaledMeshes[key] then state.scaled2DMeshes = state.scaled2DMeshes + 1 end
    end
    return scaledMeshes[key] or fallback(def, frame)
  end

  local meshWrapper = function(def, frame)
    return scaled(def, frame, rawMesh)
  end
  local shadowWrapper = function(def, frame)
    return scaled(def, frame, rawShadow)
  end

  billboards.mesh = meshWrapper
  billboards.shadowQuad = shadowWrapper
  billboards._dramaticSkyRide2DSizeHook = {
    owner = mod.id,
    rawMesh = rawMesh,
    rawShadow = rawShadow,
    meshWrapper = meshWrapper,
    shadowWrapper = shadowWrapper,
  }
  state.billboardHookInstalled = true
  if Assets.register then Assets.register(clearScaledMeshes) end
  return true
end

local function installAll()
  if not isGold() then return end
  installFlightBattleGate()
  install2DBillboardSizeHook()
end

local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousUpdate(self, dt, ...)
  if isGold() and Game.overworld == self then installAll() end
  return result
end

mod.events:on("game.ready", installAll)
mod.events:on("mods.loaded", installAll)
mod.events:on("mod.options_changed", function(payload)
  if payload and payload.mod == mod.id then
    local key = tostring(payload.key or "")
    if key == "pokedex_mount_sizes" or key:match("^mount_size_")
       or key == "flight_mount_renderer" then
      clearScaledMeshes()
    end
  elseif payload and payload.mod == PROVIDER_ID and payload.key == "sprite_style" then
    clearScaledMeshes()
  end
  installAll()
end)

mod.exports.gen2VoxelRuntimeCompat = {
  api = 2,
  battleGateInstalled = function() return state.battleGateInstalled end,
  billboardSizeHookInstalled = function() return state.billboardHookInstalled end,
  blockedGroundBattles = function() return state.blockedGroundBattles end,
  current2DScale = function() return state.last2DScale end,
  status = function()
    return {
      battleGateInstalled = state.battleGateInstalled,
      billboardSizeHookInstalled = state.billboardHookInstalled,
      blockedGroundBattles = state.blockedGroundBattles,
      scaled2DMeshes = state.scaled2DMeshes,
      nativeHgssMeshes = state.nativeHgssMeshes,
      current2DScale = state.last2DScale,
      lastError = state.lastError,
    }
  end,
}

installAll()
log("Gen2 voxel runtime compat loaded (ground battle gate; 2D sizing; native HGSS cards)")
end)();
