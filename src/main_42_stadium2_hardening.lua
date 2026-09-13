(function()
-- -------------------------------------------------------------------------
-- Stadium 2 experimental hardening layer.
--
-- Keep this isolated from the stable renderer while the native Stadium 2
-- path is being validated. It corrects the N64 skeletal rotation basis,
-- refuses incomplete/stale Crystal 251 caches, rejects unsafe DSM packs, and
-- restores Randy's Stadium 1 fallback when the native cache is unavailable.
-- -------------------------------------------------------------------------

local EXPECTED_FORMAT = "C2DSM10"
local EXPECTED_COUNT = 251
local EXPECTED_VARIANTS = 2
local warned = {}

local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
end

local function finite(value)
  value = tonumber(value)
  return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
end

local function findUpvalue(fn, wanted)
  if type(fn) ~= "function" or not (debug and debug.getupvalue) then return nil end
  for index = 1, 96 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return index, value end
  end
  return nil
end

local function replaceUpvalue(fn, wanted, value)
  if not (debug and debug.setupvalue) then return false end
  local index = findUpvalue(fn, wanted)
  if not index then return false end
  local ok = pcall(debug.setupvalue, fn, index, value)
  return ok
end

-- StadiumBuild/StadiumRig use this exact N64 Euler basis. In conventional
-- column-vector notation it is Rz * Ry * Rx. The first native DSR prototype
-- accidentally used Rx * Ry * Rz, which keeps simple bind poses plausible but
-- twists animated bones as soon as two axes rotate at once.
local function stadiumRotation3(rx, ry, rz)
  local ax = (tonumber(rx) or 0) * math.pi / 32768
  local ay = (tonumber(ry) or 0) * math.pi / 32768
  local az = (tonumber(rz) or 0) * math.pi / 32768
  local sx, cx = math.sin(ax), math.cos(ax)
  local sy, cy = math.sin(ay), math.cos(ay)
  local sz, cz = math.sin(az), math.cos(az)
  return {
    cy * cz, sx * sy * cz - cx * sz, cx * sy * cz + sx * sz,
    cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - sx * cz,
    -sy,     sx * cy,                cx * cy,
  }
end

local native = mod.exports and mod.exports.stadium3DNative or nil
local rawCacheStatus = native and native.cacheStatus or nil
local rawInstalled = native and native.installed or nil
local rawSupports = native and native.supportsSpecies or nil
local rawHasModel = native and native.hasModel or nil
local rawModelAvailable = native and native.modelAvailable or nil

local function cacheCompatibility()
  if type(rawCacheStatus) ~= "function" then
    return false, "native_status_unavailable", nil
  end
  local ok, status = pcall(rawCacheStatus)
  if not ok or type(status) ~= "table" then
    return false, "native_status_failed", nil
  end
  if not status.marker then return false, "cache_incomplete", status end
  if status.format ~= EXPECTED_FORMAT then return false, "cache_format", status end
  if (tonumber(status.count) or 0) < EXPECTED_COUNT then
    return false, "cache_count", status
  end
  if (tonumber(status.variants) or 0) < EXPECTED_VARIANTS then
    return false, "cache_variants", status
  end
  return true, nil, status
end

local function modelSafe(runtime)
  local model = runtime and runtime.model
  if type(model) ~= "table" then return false, "model_missing" end
  if model.staticPose then return false, "static_pose" end
  local dex = tonumber(runtime.dex)
  if not dex or dex < 1 or dex > EXPECTED_COUNT then return false, "dex" end
  if tonumber(model.species) ~= dex then return false, "species_mismatch" end
  local bones = tonumber(model.boneCount) or 0
  local prims = tonumber(model.primCount) or 0
  local textures = tonumber(model.texCount) or 0
  if bones < 1 or bones > 1024 then return false, "bone_count" end
  if prims < 1 or prims > 4096 then return false, "primitive_count" end
  if textures < 1 or textures > 4096 then return false, "texture_count" end
  if not finite(model.rootScale) or model.rootScale <= 0 then return false, "root_scale" end
  if not finite(model.height) or model.height <= 0 then return false, "height" end
  if not finite(model.floor) or not finite(model.radius) then return false, "bounds" end
  return true
end

local playerEnsureIndex, rawEnsureRuntime = findUpvalue(Player and Player.pose, "ensureRuntime")
local updateEnsureIndex, updateEnsureRuntime = findUpvalue(
  OverworldState and OverworldState.update, "ensureRuntime")
local _, rawPoseRuntime = findUpvalue(OverworldState and OverworldState.update, "poseRuntime")

local rotationPatched = false
if type(rawPoseRuntime) == "function" then
  rotationPatched = replaceUpvalue(rawPoseRuntime, "rotation3", stadiumRotation3)
end

-- Prefer the exact function captured by Player.pose. The update wrapper should
-- carry the same closure; keep a defensive fallback for altered load orders.
if type(rawEnsureRuntime) ~= "function" then rawEnsureRuntime = updateEnsureRuntime end

local function hardenedEnsureRuntime(species, mon)
  local compatible, reason, status = cacheCompatibility()
  if not compatible then
    warnOnce("cache:" .. tostring(reason),
      "Stadium 2 native renderer disabled: %s (format=%s count=%s variants=%s)",
      tostring(reason), tostring(status and status.format),
      tostring(status and status.count), tostring(status and status.variants))
    return nil
  end
  if type(rawEnsureRuntime) ~= "function" then return nil end
  local runtime = rawEnsureRuntime(species, mon)
  if not runtime then return nil end
  local safe, why = modelSafe(runtime)
  if not safe then
    warnOnce("model:" .. tostring(runtime.dex) .. ":" .. tostring(why),
      "Stadium 2 model #%s rejected by DSR: %s",
      tostring(runtime.dex), tostring(why))
    return nil
  end
  return runtime
end

local ensurePatched = false
if type(rawEnsureRuntime) == "function" and debug and debug.setupvalue then
  if playerEnsureIndex then
    ensurePatched = pcall(debug.setupvalue, Player.pose,
      playerEnsureIndex, hardenedEnsureRuntime) or ensurePatched
  end
  if updateEnsureIndex then
    ensurePatched = pcall(debug.setupvalue, OverworldState.update,
      updateEnsureIndex, hardenedEnsureRuntime) or ensurePatched
  end
  if native and type(native.modelInfo) == "function" then
    replaceUpvalue(native.modelInfo, "ensureRuntime", hardenedEnsureRuntime)
  end
end

-- The native provider exists as a Lua table even when Crystal 251 has not
-- completed its cache. main_28's original support probe therefore returned a
-- definitive false before Randy's provider was ever consulted. Resolve native
-- availability first, then fall through to Stadium 1 when appropriate.
local function speciesDex(species)
  if not species then return nil end
  local cfg = (ELIGIBLE and ELIGIBLE[species])
    or (GROUND_ELIGIBLE and GROUND_ELIGIBLE[species])
  if cfg and tonumber(cfg.dex) then return math.floor(tonumber(cfg.dex)) end
  local pokemon = Game and Game.data and Game.data.pokemon or nil
  local def = pokemon and pokemon[species] or nil
  local dex = def and tonumber(def.dex) or nil
  return dex and math.floor(dex) or nil
end

local function callSupport(api, species, dex)
  if type(api) ~= "table" then return nil end
  for _, name in ipairs({ "supportsSpecies", "hasModel", "modelAvailable" }) do
    local fn = api[name]
    if type(fn) == "function" then
      local ok, supported = pcall(fn, species, dex)
      if ok then return supported == true end
    end
  end
  return nil
end

local function randyHandle()
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, "STADIUM_OVERWORLD_MODELS")
  return ok and handle or nil
end

local function nativeReady()
  if not rotationPatched or not ensurePatched then return false end
  local compatible = cacheCompatibility()
  if not compatible then return false end
  if type(rawInstalled) == "function" then
    local ok, value = pcall(rawInstalled)
    return ok and value == true
  end
  return native ~= nil
end

local function nativeSupportsOnly(species, dex)
  if not nativeReady() then return false end
  for _, fn in ipairs({ rawSupports, rawHasModel, rawModelAvailable }) do
    if type(fn) == "function" then
      local ok, supported = pcall(fn, species, dex)
      if ok then return supported == true end
    end
  end
  return false
end

local function hardenedSupportsSpecies(species)
  if not species then return true end
  local dex = speciesDex(species)
  if nativeSupportsOnly(species, dex) then return true end
  local handle = randyHandle()
  local exports = handle and handle.exports or nil
  local answer = callSupport(exports, species, dex)
  if answer ~= nil then return answer end
  return handle ~= nil and dex ~= nil and dex >= 1 and dex <= 151
end

local compatibilityPatched = false
local rendering = mod.exports and mod.exports.flightRendering or nil
local effective = rendering and rendering.effective or nil
local _, rendererAvailable = findUpvalue(effective, "stadiumRendererAvailable")
if type(rendererAvailable) == "function" then
  compatibilityPatched = replaceUpvalue(rendererAvailable,
    "stadiumSupportsSpecies", hardenedSupportsSpecies)
end

if native then
  native.installed = nativeReady
  native.supportsSpecies = function(species, dex)
    return nativeSupportsOnly(species, dex or speciesDex(species))
  end
  native.hasModel = native.supportsSpecies
  native.modelAvailable = native.supportsSpecies
  native.cacheStatus = function()
    local ok, status = pcall(rawCacheStatus)
    status = ok and type(status) == "table" and status or {}
    local compatible, reason = cacheCompatibility()
    status.expectedFormat = EXPECTED_FORMAT
    status.expectedCount = EXPECTED_COUNT
    status.expectedVariants = EXPECTED_VARIANTS
    status.compatible = compatible
    status.reason = reason
    status.hardened = true
    status.operational = compatible and rotationPatched and ensurePatched
    return status
  end
end

local stadiumCompatibility = mod.exports and mod.exports.stadiumCompatibility or nil
if stadiumCompatibility then
  stadiumCompatibility.supportsSpecies = hardenedSupportsSpecies
end

mod.exports.stadium3DHardening = {
  api = 1,
  active = true,
  expectedFormat = EXPECTED_FORMAT,
  rotationPatched = rotationPatched,
  ensurePatched = ensurePatched,
  compatibilityPatched = compatibilityPatched,
  cacheCompatibility = function()
    local compatible, reason, status = cacheCompatibility()
    return { compatible = compatible, reason = reason, status = status }
  end,
}

if not rotationPatched then
  warnOnce("rotation_patch", "Stadium 2 hardening could not patch the skeletal rotation basis")
end
if not ensurePatched then
  warnOnce("ensure_patch", "Stadium 2 hardening could not install pack safety checks")
end
if not compatibilityPatched then
  warnOnce("compat_patch", "Stadium 2 hardening could not repair Stadium provider fallback")
end

log("Stadium 2 hardening loaded (rotation=%s safety=%s fallback=%s)",
  tostring(rotationPatched), tostring(ensurePatched), tostring(compatibilityPatched))
end)();
