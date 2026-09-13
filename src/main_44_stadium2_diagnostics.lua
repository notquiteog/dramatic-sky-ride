(function()
-- -------------------------------------------------------------------------
-- Compact Stadium 2 diagnostics for the experimental branch.
--
-- The native path depends on a complete Crystal 251 cache, a voxel provider,
-- and a safe model for the active mount. Log only state transitions so a user
-- report contains the useful reason without flooding the console every frame.
-- -------------------------------------------------------------------------

local lastSignature = nil
local lastModelSignature = nil

local function safeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  return ok and value or nil
end

local function bool(value)
  return value == true and "yes" or "no"
end

local function snapshot(species)
  local ex = mod.exports or {}
  local native = ex.stadium3DNative
  local hardening = ex.stadium3DHardening
  local bootstrap = ex.stadium3DCrystalBootstrap
  local bridge = ex.stadium3DProviderRig
  local fallback = ex.stadium3DFallback
  local rendering = ex.flightRendering
  local compatibility = ex.stadiumCompatibility
  local providerState = ex._dramaticProviderState or {}

  species = species or safeCall(compatibility and compatibility.activeMountSpecies)
  local cache = safeCall(native and native.cacheStatus) or {}
  local requested = safeCall(rendering and rendering.requested) or "unknown"
  local effective = safeCall(rendering and rendering.effective) or "unknown"
  local nativeInstalled = safeCall(native and native.installed) == true
  local supported = species and safeCall(native and native.supportsSpecies, species) or nil
  local model = species and nativeInstalled
    and safeCall(native and native.modelInfo, species) or nil
  local bootstrapState = safeCall(bootstrap and bootstrap.status) or {}

  return {
    species = species,
    requested = requested,
    effective = effective,
    provider = providerState.id or "none",
    cache = cache,
    nativeInstalled = nativeInstalled,
    nativeSupported = supported,
    hardening = {
      rotationPatched = hardening and hardening.rotationPatched == true,
      ensurePatched = hardening and hardening.ensurePatched == true,
      dualEnsurePatched = hardening and hardening.dualEnsurePatched == true,
      compatibilityPatched = hardening and hardening.compatibilityPatched == true,
    },
    bootstrap = bootstrapState,
    providerRig = {
      available = bridge and safeCall(bridge.available) == true,
      active = bridge and safeCall(bridge.active) == true,
    },
    fallback = {
      installed = fallback and fallback.installed == true,
      interpolated = fallback and fallback.interpolated == true,
    },
    model = model,
  }
end

local function statusSignature(s)
  local c = s.cache or {}
  local b = s.bootstrap or {}
  return table.concat({
    tostring(s.requested), tostring(s.effective), tostring(s.species),
    tostring(s.provider), tostring(c.format), tostring(c.count), tostring(c.variants),
    tostring(c.compatible), tostring(c.operational),
    tostring(s.nativeInstalled), tostring(s.nativeSupported),
    tostring(s.hardening.rotationPatched), tostring(s.hardening.ensurePatched),
    tostring(s.hardening.dualEnsurePatched),
    tostring(s.providerRig.available), tostring(s.providerRig.active),
    tostring(s.fallback.installed), tostring(s.fallback.interpolated),
    tostring(b.needed), tostring(b.installed), tostring(b.provider), tostring(b.reason),
  }, "|")
end

local function logSnapshot(s)
  local c = s.cache or {}
  local b = s.bootstrap or {}
  log("Stadium 2 status: requested=%s effective=%s mount=%s provider=%s native=%s supported=%s cache=%s/%s/%s compatible=%s operational=%s hardening=%s/%s/%s rig=%s/%s fallback=%s/%s bootstrap=%s/%s/%s",
    tostring(s.requested), tostring(s.effective), tostring(s.species or "none"),
    tostring(s.provider), bool(s.nativeInstalled),
    s.nativeSupported == nil and "n/a" or bool(s.nativeSupported),
    tostring(c.format or "none"), tostring(c.count or 0), tostring(c.variants or 0),
    bool(c.compatible), bool(c.operational),
    bool(s.hardening.rotationPatched), bool(s.hardening.ensurePatched),
    bool(s.hardening.dualEnsurePatched),
    bool(s.providerRig.available), bool(s.providerRig.active),
    bool(s.fallback.installed), bool(s.fallback.interpolated),
    bool(b.needed), tostring(b.provider or "none"), tostring(b.reason or "none"))

  local model = s.model
  if type(model) == "table" then
    local signature = table.concat({ tostring(model.dex), tostring(model.variant),
      tostring(model.bones), tostring(model.primitives), tostring(model.textures),
      tostring(model.animations), tostring(model.idleAnimation) }, "|")
    if signature ~= lastModelSignature then
      lastModelSignature = signature
      log("Stadium 2 model: %s #%03d variant=%s bones=%s prims=%s textures=%s anims=%s idle=%s height=%s floor=%s radius=%s",
        tostring(model.species), tonumber(model.dex) or 0, tostring(model.variant),
        tostring(model.bones), tostring(model.primitives), tostring(model.textures),
        tostring(model.animations), tostring(model.idleAnimation),
        tostring(model.height), tostring(model.floor), tostring(model.radius))
    end
  end
end

mod.exports.stadium3DDiagnostics = {
  api = 1,
  snapshot = snapshot,
  log = function(species)
    local state = snapshot(species)
    logSnapshot(state)
    return state
  end,
}

local previousDiagnosticsUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousDiagnosticsUpdate(self, dt, ...)
  if Game.overworld == self then
    local rendering = mod.exports and mod.exports.flightRendering or nil
    local requested = safeCall(rendering and rendering.requested)
    if requested == "stadium" then
      local state = snapshot()
      local signature = statusSignature(state)
      if signature ~= lastSignature then
        lastSignature = signature
        logSnapshot(state)
      end
    elseif lastSignature ~= nil then
      lastSignature = nil
      lastModelSignature = nil
    end
  end
  return result
end

log("Stadium 2 diagnostics loaded")
end)();
