(function()
-- -------------------------------------------------------------------------
-- Legacy Stadium 2 animation-cache guard.
--
-- Crystal 251 originally accepted geometry-only Stadium 2 imports and packed
-- a synthetic one-frame bind-pose animation when its motion decoder could not
-- resolve the separate pose table. The cache marker format stayed C2DSM10 when
-- the decoder was fixed, so those old all-static caches still look complete to
-- consumers that validate only marker/count/variant metadata.
--
-- Charizard is DSR's first visual validation mount and is known to carry real
-- Stadium motion. A valid modern cache therefore must expose more than the
-- synthetic single clip for Charizard. Mark that cache stale so the bootstrap
-- can rebuild it through a current Crystal 251 bridge + full Stadium provider.
-- -------------------------------------------------------------------------

local MARKER = "crystal_251/stadium2/pack.info"
local PROBE_SPECIES = "CHARIZARD"
local state = {
  checked = false,
  stale = false,
  reason = nil,
  animations = nil,
  invalidated = false,
}

local native = mod.exports and mod.exports.stadium3DNative or nil
local rawCacheStatus = native and native.cacheStatus or nil
local rawModelInfo = native and native.modelInfo or nil
local rawClearCache = native and native.clearCache or nil
local rawInstalled = native and native.installed or nil
local rawSupportsSpecies = native and native.supportsSpecies or nil
local rawHasModel = native and native.hasModel or nil
local rawModelAvailable = native and native.modelAvailable or nil

local function inspect()
  if state.checked then return state end
  state.checked = true
  state.stale = false
  state.reason = nil
  state.animations = nil

  if type(rawCacheStatus) ~= "function" then
    state.reason = "native_status_unavailable"
    return state
  end
  local okStatus, status = pcall(rawCacheStatus)
  if not (okStatus and type(status) == "table" and status.compatible == true) then
    state.reason = status and status.reason or "cache_not_compatible"
    return state
  end
  if type(rawModelInfo) ~= "function" then
    state.reason = "model_info_unavailable"
    return state
  end

  local okInfo, info = pcall(rawModelInfo, PROBE_SPECIES)
  if not (okInfo and type(info) == "table") then
    state.reason = "probe_model_unavailable"
    return state
  end
  state.animations = tonumber(info.animations)
  if state.animations and state.animations <= 1 then
    state.stale = true
    state.reason = "static_animation_cache"
  else
    state.reason = "animation_cache_ok"
  end
  return state
end

local function animationUsable()
  return inspect().stale ~= true
end

local function invalidateMarker()
  local current = inspect()
  if not current.stale then return false, current.reason end
  local fs = love and love.filesystem or nil
  if not (fs and type(fs.remove) == "function") then
    return false, "filesystem_remove_unavailable"
  end
  local ok, removed = pcall(fs.remove, MARKER)
  if not ok then return false, tostring(removed) end
  if removed == false then return false, "marker_remove_failed" end
  if type(rawClearCache) == "function" then pcall(rawClearCache) end
  state.invalidated = true
  state.checked = false
  state.stale = false
  state.reason = "marker_invalidated"
  log("Stadium 2 legacy static cache invalidated; Crystal 251 rebuild required")
  return true
end

if native and type(rawCacheStatus) == "function" then
  native.cacheStatus = function()
    local ok, status = pcall(rawCacheStatus)
    status = ok and type(status) == "table" and status or {}
    local check = inspect()
    status.animationProbe = PROBE_SPECIES
    status.animationCount = check.animations
    status.animationCompatible = not check.stale
    status.animationReason = check.reason
    if check.stale then
      status.compatible = false
      status.operational = false
      status.reason = check.reason
    end
    return status
  end

  -- A legacy cache should never keep rendering silently just because its DSM
  -- geometry is structurally valid. Until it is rebuilt, expose the same
  -- defensive "unavailable" answer as a corrupt/missing native pack so the
  -- normal Stadium-1/2D fallback hierarchy remains intact.
  native.installed = function(...)
    if not animationUsable() then return false end
    if type(rawInstalled) ~= "function" then return true end
    local ok, value = pcall(rawInstalled, ...)
    return ok and value == true
  end
  native.supportsSpecies = function(...)
    if not animationUsable() then return false end
    if type(rawSupportsSpecies) ~= "function" then return false end
    local ok, value = pcall(rawSupportsSpecies, ...)
    return ok and value == true
  end
  native.hasModel = function(...)
    if not animationUsable() then return false end
    local fn = type(rawHasModel) == "function" and rawHasModel or rawSupportsSpecies
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    return ok and value == true
  end
  native.modelAvailable = function(...)
    if not animationUsable() then return false end
    local fn = type(rawModelAvailable) == "function" and rawModelAvailable or rawSupportsSpecies
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    return ok and value == true
  end
end

mod.exports.stadium3DAnimationCacheGuard = {
  api = 2,
  inspect = function()
    local s = inspect()
    return {
      checked = s.checked,
      stale = s.stale,
      reason = s.reason,
      animations = s.animations,
      invalidated = s.invalidated,
      probeSpecies = PROBE_SPECIES,
    }
  end,
  usable = animationUsable,
  invalidateMarker = invalidateMarker,
}

local initial = inspect()
if initial.stale then
  if mod.log and mod.log.warn then
    pcall(mod.log.warn, mod.log,
      "Stadium 2 cache contains only the one-frame Charizard fallback; treating it as stale")
  end
else
  log("Stadium 2 animation cache guard loaded (%s, animations=%s)",
    tostring(initial.reason), tostring(initial.animations))
end
end)();
