(function()
-- -------------------------------------------------------------------------
-- STADIUM_OVERWORLD_MODELS interoperability.
--
-- Randy's companion and Crystal-aware forks intentionally recognize DSR mount
-- sprites through dramaticSkyRideMountSpecies / SKY_RIDE_<SPECIES>. That is the
-- correct contract when the companion is the renderer. It becomes a conflict
-- when DSR's native Stadium 2 path is already presenting the same mount: both
-- systems can claim one pose and independently build/animate a Stadium model.
--
-- Native DSR sentinels therefore opt out of the generic companion contract.
-- Ordinary DSR 2D mount sprites keep their existing tags, so an installed
-- STADIUM_OVERWORLD_MODELS build can still act as the external fallback/provider
-- whenever DSR native Stadium 2 is unavailable or not selected.
--
-- The ROM picker is deliberately treated as a separate capability. Compatible
-- forks may expose a convenient selection UI, but Crystal's actual Stadium 2
-- cache builder still needs a full importer host (see main_46).
-- -------------------------------------------------------------------------

local warned = {}
local suppressedDefs = setmetatable({}, { __mode = "k" })
local suppressedCount = 0

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

local function companionHandle()
  return safeFind("STADIUM_OVERWORLD_MODELS")
end

local function crystalHandle()
  return safeFind("CRYSTAL_251") or safeFind("crystal_251")
end

local function companionExports()
  local handle = companionHandle()
  return handle, handle and handle.exports or nil
end

local function pickerFunction()
  local handle, ex = companionExports()
  if not ex then return nil, handle end
  if type(ex.chooseStadiumRom) == "function" then
    return function(game) return ex.chooseStadiumRom(game) end, handle
  end
  local menu = ex.romMenu
  if type(menu) == "table" and type(menu.choose) == "function" then
    return function(game) return menu.choose(game) end, handle
  end
  return nil, handle
end

local function nativeDefinition(def)
  return type(def) == "table" and def.dramaticSkyRideStadiumNative == true
end

local function suppressCompanionClaim(def)
  if not nativeDefinition(def) then return false end
  if not suppressedDefs[def] then
    suppressedDefs[def] = true
    suppressedCount = suppressedCount + 1
    def._dsrNativeMountSpecies = def._dsrNativeMountSpecies
      or def.dramaticSkyRideMountSpecies or def.skyRideMountSpecies
  end

  -- OverworldStadium resolves the DSR-specific species tag before generic
  -- stadiumModel=false metadata. Remove the advertising tag itself, then keep
  -- the explicit opt-out as a second guard for compatible forks that inspect
  -- generic Pokemon metadata first.
  def.dramaticSkyRideMountSpecies = nil
  def.skyRideMountSpecies = nil
  def.stadiumModel = false
  def.pokemonModel = false
  return true
end

local previousPose = Player and Player.pose or nil
local posePatched = false
if type(previousPose) == "function" then
  function Player:pose(...)
    local sprite, px, py, facing, phase, flip, hopping = previousPose(self, ...)
    local def = sprite and sprite.def or nil
    if nativeDefinition(def) then suppressCompanionClaim(def) end
    return sprite, px, py, facing, phase, flip, hopping
  end
  posePatched = true
end

local function companionCanRender(species, dex)
  local _, ex = companionExports()
  if not ex then return nil end
  for _, api in ipairs({ ex, ex.overworld }) do
    if type(api) == "table" then
      for _, name in ipairs({ "supportsSpecies", "hasModel", "modelAvailable" }) do
        local fn = api[name]
        if type(fn) == "function" then
          local ok, value = pcall(fn, species, dex)
          if ok then return value == true end
        end
      end
    end
  end
  local ow = ex.overworld
  if type(ow) == "table" and type(ow.canRenderEntity) == "function" and dex then
    local probe = {
      stadiumDex = dex, pokemonDex = dex,
      stadiumSpecies = species, pokemonSpecies = species,
      stadiumModel = true, pokemonModel = true,
    }
    local ok, value = pcall(ow.canRenderEntity, probe)
    if ok then return value == true end
  end
  return nil
end

local function upstreamPicker(game)
  local choose = pickerFunction()
  if not choose then return false, "stadium_overworld_picker_unavailable" end
  local ok, value = pcall(choose, game or Game)
  if not ok then return false, tostring(value) end
  return value ~= false, value
end

local function status()
  local handle, ex = companionExports()
  local picker = pickerFunction()
  local bootstrap = mod.exports and mod.exports.stadium3DCrystalBootstrap or nil
  local bootstrapStatus = bootstrap and type(bootstrap.status) == "function"
    and select(2, pcall(bootstrap.status)) or nil
  if type(bootstrapStatus) ~= "table" then bootstrapStatus = nil end
  return {
    companion = handle ~= nil,
    companionId = handle and handle.id or nil,
    companionVersion = ex and ex.version or nil,
    companionRendererInstalled = ex and ex.rendererInstalled == true or false,
    romPicker = type(picker) == "function",
    crystal251 = crystalHandle() ~= nil,
    importHost = bootstrapStatus and bootstrapStatus.provider or nil,
    importSurface = bootstrapStatus and bootstrapStatus.importSurface or nil,
    importReason = bootstrapStatus and bootstrapStatus.reason or nil,
    nativePoseArbitration = posePatched,
    nativeDefinitionsSuppressed = suppressedCount,
  }
end

mod.exports.stadium3DProviderInterop = {
  api = 1,
  status = status,
  companionCanRender = companionCanRender,
  chooseUpstreamStadiumRom = upstreamPicker,
  suppressNativeDefinition = suppressCompanionClaim,
}

if companionHandle() then
  log("STADIUM_OVERWORLD_MODELS interop loaded (native mount ownership arbitration + capability probing)")
elseif not posePatched then
  warnOnce("pose", "Stadium provider interop could not attach native mount ownership arbitration")
end
end)();
