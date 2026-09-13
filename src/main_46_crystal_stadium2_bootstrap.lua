(function()
-- -------------------------------------------------------------------------
-- Crystal 251 Stadium 2 cache bootstrap.
--
-- DSR's native renderer deliberately separates two jobs:
--   * a voxel provider supplies Voxel3D/ShadowMap/Mat4 for presentation;
--   * an import host supplies the full Stadium builder module family Crystal
--     251 needs to turn the user's Stadium 2 ROM into DSM4 packs.
--
-- Dramaless/Dramatic Shape are known full import hosts. Battle Art is a valid
-- renderer but currently does not ship the full Stadium importer family. Some
-- STADIUM_OVERWORLD_MODELS forks expose their own ROM UI and may proxy a full
-- compatible host, so selection is capability-based rather than hard-coded to
-- one mod name. This also lets future/legacy forks work when they preserve the
-- same public importer module contract.
--
-- IMPORTANT: cache readiness and bridge/UI installation are independent.
-- A valid Stadium 2 cache must never cause this bootstrap to return before
-- Crystal's bridge is attached to the active full import host. The bridge is
-- what patches the host's Stadium picker from STADIUM ROM to STADIUM 2 ROM and
-- provides the STADIUM 2 MODELS row. Keeping it attached after a successful
-- import means the row remains visible as READY on later boots and can be used
-- to reimport without deleting the existing cache.
--
-- Crystal's historical Stadium 2 importer also produced valid-looking
-- C2DSM10 caches containing only a synthetic one-frame bind pose when motion
-- extraction failed. main_46a detects those legacy caches. If a current
-- Crystal bridge with the fixed motion decoder is installed, this bootstrap
-- invalidates only the completion marker and lets Crystal rebuild the DSM
-- files from the user's ROM through any compatible full import host.
-- -------------------------------------------------------------------------

local state = {
  attempts = 0,
  installed = false,
  uiAttached = false,
  crystal = false,
  provider = nil,
  importSurface = nil,
  needed = nil,
  cacheReady = false,
  reason = nil,
  invalidatedStaticCache = false,
  bridgeSource = nil,
}
local warned = {}

local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
end

local function safeFind(id)
  if not (mod and mod.find) then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

local function cacheStatus()
  local native = mod.exports and mod.exports.stadium3DNative or nil
  local fn = native and native.cacheStatus
  if type(fn) ~= "function" then return {} end
  local ok, status = pcall(fn)
  return ok and type(status) == "table" and status or {}
end

local function cacheCompatible()
  return cacheStatus().compatible == true
end

local function crystalHandle()
  return safeFind("CRYSTAL_251") or safeFind("crystal_251")
end

local REQUIRED_IMPORT_MODULES = {
  "StadiumRig", "StadiumBuild", "StadiumFragment",
  "StadiumInstall", "StadiumRom", "StadiumFx",
}

local function providerHasImporterModules(handle)
  local V = handle and handle.exports and handle.exports.lib or nil
  if not (V and type(V.require) == "function") then return false end
  for _, name in ipairs(REQUIRED_IMPORT_MODULES) do
    local ok, value = pcall(V.require, name)
    if not (ok and type(value) == "table") then return false end
  end
  return true
end

-- Do not equate a mod id with importer capability. A fork may preserve the
-- complete Stadium module family under a different id, while a renderer fork
-- may intentionally omit it. Known ecosystem handles are therefore probed in a
-- stable order and accepted only when every module Crystal actually needs is
-- available.
local function fullStadiumProvider()
  local candidates = {
    { "DRAMALESS_SHAPE", "DRAMALESS_SHAPE" },
    { "dramaticless_shape", "DRAMALESS_SHAPE" },
    { "DRAMATIC_SHAPE", "DRAMATIC_SHAPE" },
    { "dramatic_shape", "DRAMATIC_SHAPE" },
    { "STADIUM_OVERWORLD_MODELS", "STADIUM_OVERWORLD_MODELS" },
    { "BATTLE_ART_VOXEL_FORK", "BATTLE_ART_VOXEL_FORK" },
  }
  local seen = {}
  for _, row in ipairs(candidates) do
    local handle = safeFind(row[1])
    if handle and not seen[handle] then
      seen[handle] = true
      if providerHasImporterModules(handle) then return handle, row[2] end
    end
  end
  return nil
end

-- STADIUM_OVERWORLD_MODELS exposes a convenient ROM selection surface in
-- Randy's implementation and compatible forks. It is useful independently of
-- whether that mod owns the importer itself, so report it separately instead
-- of misclassifying a menu wrapper as a full builder host.
local function stadiumImportSurface()
  local handle = safeFind("STADIUM_OVERWORLD_MODELS")
  local ex = handle and handle.exports or nil
  if not ex then return nil end
  if type(ex.chooseStadiumRom) == "function" then
    return handle, "STADIUM_OVERWORLD_MODELS"
  end
  local menu = ex.romMenu
  if type(menu) == "table" and type(menu.choose) == "function" then
    return handle, "STADIUM_OVERWORLD_MODELS"
  end
  return nil
end

-- Crystal only exports crystalStadium2 after its own install() succeeds against
-- a provider it discovered. With renderer-only setups that export can be nil,
-- even though the bridge module itself is present and is explicitly designed
-- to accept a provider argument. Load the module directly as the fallback.
local function crystalBridge(crystal)
  local exported = crystal and crystal.exports and crystal.exports.crystalStadium2 or nil
  if type(exported) == "table" and type(exported.install) == "function" then
    state.bridgeSource = "export"
    return exported
  end
  local ok, bridge = pcall(require, "mods.CRYSTAL_251.lib.stadium2_bridge")
  if ok and type(bridge) == "table" and type(bridge.install) == "function" then
    state.bridgeSource = "module"
    return bridge
  end
  state.bridgeSource = nil
  return nil
end

local function bridgeHasFixedMotionDecoder(bridge)
  local test = bridge and bridge._test or nil
  return type(test) == "table"
    and type(test.decodeAnimationSources) == "function"
    and type(test.poseSourcesForRecord) == "function"
end

local function invalidateLegacyStaticCache(bridge, status)
  if not (status and status.animationReason == "static_animation_cache") then
    return true
  end
  if not bridgeHasFixedMotionDecoder(bridge) then
    state.reason = "crystal_251_motion_decoder_too_old"
    warnOnce("old_crystal_motion_decoder",
      "Stadium 2 cache is a legacy one-frame cache, but this Crystal 251 build does not expose the fixed Stadium 2 motion decoder. Update Crystal 251 before rebuilding the cache.")
    return false
  end
  local guard = mod.exports and mod.exports.stadium3DAnimationCacheGuard or nil
  if not (guard and type(guard.invalidateMarker) == "function") then
    state.reason = "animation_cache_guard_missing"
    return false
  end
  local ok, removed, why = pcall(guard.invalidateMarker)
  if not ok or removed ~= true then
    state.reason = "static_cache_invalidation_failed"
    warnOnce("static_cache_invalidation",
      "Could not invalidate legacy static Stadium 2 cache marker: %s",
      tostring(ok and why or removed))
    return false
  end
  state.invalidatedStaticCache = true
  state.reason = "static_cache_invalidated"
  return true
end

local function tryBootstrap(reason)
  state.attempts = state.attempts + 1
  local status = cacheStatus()
  state.cacheReady = status.compatible == true
  state.needed = not state.cacheReady

  -- Do NOT return merely because the pack is ready. The Crystal bridge owns
  -- the persistent Stadium 2 options/picker integration and must be attached
  -- on every boot where a compatible full import host is available.
  local crystal = crystalHandle()
  state.crystal = crystal ~= nil
  if not crystal then
    state.reason = state.cacheReady and "cache_ready_crystal_251_missing"
      or "crystal_251_missing"
    return state.cacheReady
  end

  local bridge = crystalBridge(crystal)
  if not bridge then
    state.reason = state.cacheReady and "cache_ready_bridge_unavailable"
      or "crystal_251_bridge_unavailable"
    return state.cacheReady
  end

  local surface, surfaceId = stadiumImportSurface()
  state.importSurface = surfaceId

  local provider, providerId = fullStadiumProvider()
  state.provider = providerId
  if not provider then
    local battleArt = safeFind("BATTLE_ART_VOXEL_FORK") ~= nil
    if state.cacheReady then
      -- Rendering can continue from the persistent DSM cache, but there is no
      -- full builder host available to expose a functional reimport action.
      state.reason = surface and "cache_ready_import_surface_without_builder"
        or (battleArt and "cache_ready_battle_art_renderer_only"
          or "cache_ready_without_import_host")
      return true
    end
    if surface then
      state.reason = battleArt and "battle_art_import_surface_without_builder"
        or "stadium_import_surface_without_builder"
      warnOnce("surface_without_builder",
        "%s exposes a Stadium ROM picker, but the active renderer stack does not expose the full Stadium importer module family Crystal 251 needs. DSR can still use an existing Stadium 2 cache, but this picker alone cannot build one.",
        tostring(surfaceId))
    elseif battleArt then
      state.reason = "battle_art_requires_prebuilt_cache"
      warnOnce("battle_art_cache",
        "Native Stadium 2 cache is not ready. Battle Art can render DSR's DSM mounts but does not currently expose the full Crystal 251 Stadium importer module family. A compatible import host or an existing cache is required.")
    else
      state.reason = "stadium_import_provider_missing"
    end
    return false
  end

  -- Only invalidate a legacy static marker when reconstruction is genuinely
  -- required. A healthy READY cache is never touched just to restore the UI.
  if not state.cacheReady and not invalidateLegacyStaticCache(bridge, status) then
    return false
  end

  local options = {
    count = 251,
    ownerId = tostring(crystal.id or "CRYSTAL_251"),
    ownerName = "Crystal 251",
  }
  local ok, active = pcall(bridge.install, crystal, nil, provider, options)
  if not ok or not active then
    state.reason = state.cacheReady and "cache_ready_bridge_attach_failed"
      or "bridge_install_failed"
    warnOnce("install:" .. tostring(providerId),
      "Could not attach Crystal 251's Stadium 2 importer to %s: %s",
      tostring(providerId), tostring(active))
    return state.cacheReady
  end

  state.installed = true
  state.uiAttached = true
  state.provider = providerId
  if state.cacheReady then
    state.reason = "cache_ready_bridge_attached"
  elseif state.invalidatedStaticCache then
    state.reason = "rebuild_attached"
  else
    state.reason = reason or "installed"
  end
  log("Crystal 251 Stadium 2 bridge attached to %s (bridge=%s, importSurface=%s, cacheReady=%s, rebuild=%s)",
    tostring(providerId), tostring(state.bridgeSource), tostring(state.importSurface),
    tostring(state.cacheReady), tostring(state.invalidatedStaticCache))
  return true
end

tryBootstrap("load")
if mod.events and mod.events.on then
  mod.events:on("game.ready", function()
    -- Provider/UI modules may finish installing after DSR's initial load. Retry
    -- once at game.ready whether or not the cache already exists: READY packs
    -- still need the bridge so STADIUM 2 ROM remains visible.
    if not state.installed then tryBootstrap("game.ready") end
  end)
end

mod.exports.stadium3DCrystalBootstrap = {
  api = 4,
  retry = tryBootstrap,
  status = function()
    local status = cacheStatus()
    state.cacheReady = status.compatible == true
    state.needed = not state.cacheReady
    return {
      attempts = state.attempts,
      installed = state.installed,
      uiAttached = state.uiAttached,
      crystal = state.crystal,
      provider = state.provider,
      importSurface = state.importSurface,
      needed = state.needed,
      cacheReady = state.cacheReady,
      reason = state.reason,
      invalidatedStaticCache = state.invalidatedStaticCache,
      bridgeSource = state.bridgeSource,
      animationReason = status.animationReason,
      animationCount = status.animationCount,
    }
  end,
}
end)();
