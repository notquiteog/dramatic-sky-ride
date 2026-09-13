
(function()
-- -------------------------------------------------------------------------
-- Capability-based follower / sprite compatibility.
--
-- Wilds of Kanto owns its own follower runtime and can also expose the active
-- sprite style. Keep those two concerns separate: use one authoritative
-- follower runtime, but allow any compatible public sprite provider to feed
-- Sky Ride without bypassing the existing mount-size / rider wrappers.
-- -------------------------------------------------------------------------
local WILDS_MOD_ID = "overworld_wild_spawns"
local SPRITE_PROVIDER_IDS = {
  WILDS_MOD_ID,
  "PokePCFollowers_VoxelMerge",
  "pokepcfollowers",
  "FOLLOWERS_EX",
  "followers_ex",
}

local function compatExports(id)
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle and handle.exports or nil
end

local function usableProviderDefinition(id, ex, species, role, style)
  if not (ex and type(ex.resolveFollowerSprite) == "function") then return nil end
  local opts = {
    species = species,
    surface = "land",
    role = role or "mount",
    game = Game,
  }
  if style then opts.style = style end
  local okDef, provided = pcall(ex.resolveFollowerSprite, opts)
  local frames = provided and tonumber(provided.frames) or 0
  if not (okDef and provided and provided.image and frames >= 6) then return nil end
  local okImage, image = pcall(Assets.image, provided.image)
  if not (okImage and image) then return nil end
  local width, height = image:getDimensions()
  if width < 16 or height < 96 then return nil end
  return provided, provided.providerId or id
end

local function compatibleSpriteDefinition(species, role)
  for _, id in ipairs(SPRITE_PROVIDER_IDS) do
    local ex = compatExports(id)
    local def, provider = usableProviderDefinition(id, ex, species, role, nil)
    if def then return def, provider end
    if id == WILDS_MOD_ID then
      -- Wilds' Pokédex style may resolve to a static front image. The built-in
      -- follower/GSC style is always the safe walking-sheet fallback for a
      -- rideable mount while still requiring no separate PokéPC install.
      def, provider = usableProviderDefinition(id, ex, species, role, "followers")
      if def then return def, provider end
    end
  end
  return nil
end

local lastCompatSpriteProvider = nil
local function providerPath(species, role)
  local def, provider = compatibleSpriteDefinition(species, role)
  if not def then return nil end
  if provider ~= lastCompatSpriteProvider then
    log("Mount sprite provider: %s", tostring(provider))
    lastCompatSpriteProvider = provider
  end
  return def.image
end

-- Replace only the path resolvers. The existing buildMountSprite and
-- buildGroundMountSprite chains remain intact, including main_21's Pokédex
-- size decorator and every previously validated rider/voxel hook.
local legacyFollowerPath = followerPath
followerPath = function(species)
  return providerPath(species, "flight_mount") or legacyFollowerPath(species)
end

local legacyGroundFollowerPath = groundFollowerPath
groundFollowerPath = function(species)
  return providerPath(species, "ground_mount") or legacyGroundFollowerPath(species)
end

-- Wilds is authoritative when installed: asking PokéPC / Followers EX to sync
-- after Wilds would create competing lifecycle owners. A successful Wilds
-- sync is authoritative even when the configured follower count is zero.
local legacySyncFollowerMods = syncFollowerMods
syncFollowerMods = function(ow)
  local wilds = compatExports(WILDS_MOD_ID)
  if wilds and type(wilds.syncAll) == "function" then
    local ok, err = pcall(wilds.syncAll, Game, ow)
    if not ok then
      log("Wilds follower sync failed: %s", tostring(err))
      return false
    end
    return true
  end
  return legacySyncFollowerMods(ow)
end

-- -------------------------------------------------------------------------
-- Cooperative update-hook guard.
-- -------------------------------------------------------------------------
local skyRideRootUpdate = OverworldState.update
local skyRideUpdateHeartbeat = 0
local skyRideHookRecoveries = 0

local DSR_UPDATE_LINK_NAMES = {
  gen2Update = true,
  previousGoldSuicuneUpdate = true,
  previousGen1SurfUpdate = true,
  wildSkiesUpdate = true,
  storyRuleUpdate = true,
  lot1Update = true,
  seamUpdate = true,
  waterUpdate = true,
  polishUpdate = true,
  groundUpdate = true,
  update = true,
}

-- Watchdog-style mods such as Wild Skies legitimately wrap the complete DSR
-- update root. A frame can skip the overworld tick during a transition, so a
-- missed heartbeat alone does not mean that DSR was displaced. Detect the
-- already-composed root before attempting any boundary surgery; rebinding an
-- inner DSR link to an outer wrapper would otherwise create a loop and amputate
-- the flight/Surf layers that precede this compatibility part.
local function functionGraphContains(root, target)
  if root == target then return true end
  if type(root) ~= "function" or type(target) ~= "function"
      or not (debug and debug.getupvalue) then return false end
  local seen = {}
  local remaining = 96
  local function visit(fn)
    if fn == target then return true end
    if type(fn) ~= "function" or seen[fn] or remaining <= 0 then return false end
    seen[fn] = true
    remaining = remaining - 1
    local index = 1
    while true do
      local ok, name, value = pcall(debug.getupvalue, fn, index)
      if not ok or not name then break end
      if type(value) == "function" and visit(value) then return true end
      index = index + 1
    end
    return false
  end
  return visit(root)
end

local function dsrChildLink(fn)
  if type(fn) ~= "function" or not (debug and debug.getupvalue and debug.setupvalue) then
    return nil, nil, nil
  end
  local index = 1
  while true do
    local name, value = debug.getupvalue(fn, index)
    if not name then return nil, nil, nil end
    if DSR_UPDATE_LINK_NAMES[name] and type(value) == "function" then
      return index, value, name
    end
    index = index + 1
  end
end

local function discoverDsrBoundary(root)
  local chain = {}
  local seen = {}
  local current = root
  while type(current) == "function" and not seen[current] do
    seen[current] = true
    chain[#chain + 1] = current
    local index, child, name = dsrChildLink(current)
    if not index then break end
    local childIndex = select(1, dsrChildLink(child))
    if not childIndex then
      return current, index, child, chain, name
    end
    current = child
  end
  return nil, nil, nil, chain, nil
end

local boundaryParent, boundaryIndex, initialExternal, dsrChain =
  discoverDsrBoundary(skyRideRootUpdate)
local dsrFunctionSet = {}
for _, fn in ipairs(dsrChain or {}) do dsrFunctionSet[fn] = true end
local skyRideGuardReady = boundaryParent ~= nil and boundaryIndex ~= nil

local function bindExternal(nextUpdate)
  if not skyRideGuardReady or type(nextUpdate) ~= "function" then return false end
  local function heartbeatExternal(self, dt, ...)
    skyRideUpdateHeartbeat = skyRideUpdateHeartbeat + 1
    return nextUpdate(self, dt, ...)
  end
  debug.setupvalue(boundaryParent, boundaryIndex, heartbeatExternal)
  return true
end

if skyRideGuardReady then bindExternal(initialExternal) end

local function recordRecovery(reason)
  skyRideHookRecoveries = skyRideHookRecoveries + 1
  log("Mount update hook was displaced; full DSR chain reattached (%s)",
      tostring(reason or "heartbeat"))
end

local function composeSkyRideAround(current, reason, countRecovery)
  if not skyRideGuardReady or type(current) ~= "function" then return nil end
  if current == skyRideRootUpdate then return skyRideRootUpdate end
  if functionGraphContains(current, skyRideRootUpdate) then return current end
  if dsrFunctionSet[current] then
    if countRecovery ~= false then recordRecovery(reason or "intermediate DSR wrapper") end
    return skyRideRootUpdate
  end
  if not bindExternal(current) then return nil end
  if countRecovery ~= false then recordRecovery(reason or "cooperative composition") end
  return skyRideRootUpdate
end

local function recoverSkyRideUpdate(reason)
  if not skyRideGuardReady then return false end
  local current = OverworldState.update
  if current == skyRideRootUpdate then return true end
  if type(current) ~= "function" then return false end
  if functionGraphContains(current, skyRideRootUpdate) then return true end
  local composed = composeSkyRideAround(current, reason, true)
  if not composed then return false end
  OverworldState.update = composed
  return true
end

local function skyRideRuntimeActive()
  if flight.active or (ground and ground.active) then return true end
  -- Visible Surf is activated from OverworldState:update itself. If another
  -- watchdog displaced DSR before that first tick, the private water state is
  -- still false; use the engine's authoritative Surf flag to bootstrap the
  -- recovery instead of waiting on state that cannot yet be created.
  local ow = Game.overworld
  if ow and ow.player and ow.player.surfing == true then return true end
  local isWater = mod.exports and mod.exports.isWaterRiding
  if type(isWater) == "function" then
    local ok, active = pcall(isWater)
    if ok and active == true then return true end
  end
  return false
end

local gameStepBeforeCompat = Game.step
if skyRideGuardReady and type(gameStepBeforeCompat) == "function" then
  local function gameStepCompatGuard(...)
    local owBefore = Game.overworld
    local stackBefore = Game.stack
    local topBefore = stackBefore and stackBefore.top and stackBefore:top() or nil
    local expectedOverworldTick = owBefore ~= nil
      and (not stackBefore or topBefore == owBefore)
    local before = skyRideUpdateHeartbeat
    local a, b, c, d, e = gameStepBeforeCompat(...)
    local owAfter = Game.overworld
    local stackAfter = Game.stack
    local topAfter = stackAfter and stackAfter.top and stackAfter:top() or nil
    local stillInOverworld = owAfter ~= nil
      and (not stackAfter or topAfter == owAfter)
    if skyRideRuntimeActive() and expectedOverworldTick and stillInOverworld
        and skyRideUpdateHeartbeat == before then
      recoverSkyRideUpdate("active-mount logic heartbeat")
    end
    return a, b, c, d, e
  end
  Game.step = gameStepCompatGuard
end

if skyRideGuardReady then
  log("DSR update-chain guard armed (%d wrappers)", #(dsrChain or {}))
else
  log("DSR update-chain guard unavailable; wrapper boundary not found")
end

mod.exports.wildsCompatibility = {
  wildsId = WILDS_MOD_ID,
  spriteProviders = SPRITE_PROVIDER_IDS,
  ensureUpdateHook = recoverSkyRideUpdate,
  composeAround = function(current, reason)
    return composeSkyRideAround(current, reason or "cooperative recovery", true)
  end,
  rootUpdate = function() return skyRideRootUpdate end,
  ownsUpdate = function(fn) return dsrFunctionSet[fn] == true end,
  hookGuardReady = function() return skyRideGuardReady end,
  hookRecoveries = function() return skyRideHookRecoveries end,
  updateHeartbeat = function() return skyRideUpdateHeartbeat end,
  protectedWrappers = function() return #(dsrChain or {}) end,
}
end)();
