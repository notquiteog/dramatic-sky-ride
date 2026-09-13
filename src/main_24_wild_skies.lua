(function()
-- Optional Wild Skies integration.
-- Wild Skies remains an independent mod and owns its flyers, ecology,
-- persistence and rendering. DSR only advertises its airborne state and uses
-- documented Wild Skies exports to consume a flyer for an aerial encounter.

local WILD_SKIES_SOURCE_ID = "dramatic_sky_ride_followers"
local WILDS_MOD_ID = "overworld_wild_spawns"
local WILD_SKIES_INTERCEPT_RADIUS = 1
local WILD_SKIES_PHYSICAL_RADIUS = 14
local WILD_SKIES_ALTITUDE_RADIUS = 20
local WILD_SKIES_BATTLE_REST = 25
local DOUBLE_BATTLES_SOURCE_ID = "dramatic_sky_ride_flock"
local FALLBACK_PROVIDER_IDS = {
  "PokePCFollowers_VoxelMerge",
  "pokepcfollowers",
  "FOLLOWERS_EX",
  "followers_ex",
}

local wildSkies = {
  handle = nil,
  take = nil,
  registered = false,
  spriteMode = "native",
  cooldown = 0,
  battleRest = 0,
  lastIntercept = nil,
  lastQueueError = nil,
  sceneryInterceptCount = 0,
  interceptCount = 0,
  doubleBattlesRegistered = false,
}

local function enabledModHandle(id)
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

local function wildSkiesHandle()
  if wildSkies.handle ~= nil then return wildSkies.handle or nil end
  wildSkies.handle = enabledModHandle("wild_skies") or false
  return wildSkies.handle or nil
end

local function isGen2Runtime(game)
  local runtime = mod.exports.runtimeGeneration
  local check = runtime and runtime.isGen2
  if type(check) ~= "function" then return false end
  local ok, value = pcall(check, game or Game)
  return ok and value == true
end

local function wildsEnabled()
  return enabledModHandle(WILDS_MOD_ID) ~= nil
end

local function fallbackProvider()
  for _, id in ipairs(FALLBACK_PROVIDER_IDS) do
    local handle = enabledModHandle(id)
    local exports = handle and handle.exports
    if exports and type(exports.resolveFollowerSprite) == "function" then
      return id, exports
    end
  end
  return nil
end

-- Gen 1 compatibility only. Wild Skies 1.9 owns the full Gold sprite-source
-- ladder (native Gold, Wilds/HGSS, embedded Wilds/Stadium 2, registered packs),
-- so DSR must not outrank it with follower land art on Gen 2.
local function fallbackAirSprite(game, species, dex)
  local providerId, exports = fallbackProvider()
  if not exports then return nil end
  game = game or Game
  local ok, provided = pcall(exports.resolveFollowerSprite, {
    species = species,
    speciesId = tonumber(dex),
    surface = "land",
    role = "wild_skies_airborne_fallback",
    game = game,
  })
  if not (ok and type(provided) == "table"
      and type(provided.image) == "string") then
    return nil
  end
  local frames = tonumber(provided.frames) or 0
  if frames < 2 then return nil end
  return {
    id = provided.id or ("DSR_WILD_SKIES_" .. tostring(species)),
    image = provided.image,
    frames = frames,
    walker = provided.walker ~= false,
    trueColor = provided.trueColor ~= false,
    providerId = provided.providerId or providerId,
  }
end

local lastSpriteMode = nil
local function setSpriteMode(mode)
  wildSkies.spriteMode = mode
  if mode ~= lastSpriteMode then
    lastSpriteMode = mode
    log("Wild Skies sprite integration: %s", tostring(mode))
  end
end

local function configureWildSkiesSpriteSource()
  local handle = wildSkiesHandle()
  local exports = handle and handle.exports
  if not exports then
    wildSkies.registered = false
    setSpriteMode("wild_skies_unavailable")
    return false
  end

  if type(exports.unregisterSpriteSource) == "function" then
    pcall(exports.unregisterSpriteSource, WILD_SKIES_SOURCE_ID)
  end
  wildSkies.registered = false

  if isGen2Runtime(Game) then
    setSpriteMode("gen2_wild_skies_native")
    return true
  end

  if wildsEnabled() then
    setSpriteMode("gen1_wild_skies_native_wilds")
    return true
  end

  local providerId = fallbackProvider()
  if not providerId then
    setSpriteMode("gen1_wild_skies_native")
    return true
  end

  local register = exports.registerSpriteSource
  if type(register) ~= "function" then
    setSpriteMode("gen1_wild_skies_no_sprite_api")
    return false
  end

  local source = {
    id = WILD_SKIES_SOURCE_ID,
    resolve = function(_, game, species, dex)
      return fallbackAirSprite(game, species, dex)
    end,
  }
  local ok, accepted = pcall(register, source)
  wildSkies.registered = ok and accepted ~= false
  if wildSkies.registered then
    setSpriteMode("gen1_dsr_fallback_" .. tostring(providerId))
  else
    setSpriteMode("gen1_wild_skies_fallback_rejected")
  end
  return wildSkies.registered
end

local function clearWildSkiesAirborneMarker(ow)
  local p = ow and ow.player
  if not (p and p.dramaticSkyRideFreeFlying) then return end
  p.freeFlying = nil
  p.dramaticSkyRideFreeFlying = nil
end

local function syncWildSkiesAirborneMarker(ow)
  local p = ow and ow.player
  if not p then return end
  if flight.active then
    p.freeFlying = true
    p.dramaticSkyRideFreeFlying = true
  else
    clearWildSkiesAirborneMarker(ow)
  end
end

local function wildSkiesTakeFlyer()
  if wildSkies.take ~= nil then return wildSkies.take or nil end
  local handle = wildSkiesHandle()
  local take = handle and handle.exports and handle.exports.takeFlyer
  wildSkies.take = type(take) == "function" and take or false
  return wildSkies.take or nil
end

-- Wild Skies intentionally exposes only "bold" flyers through takeFlyer().
-- In DSR, AIR ENCOUNTERS means a literal mid-air collision should be actionable,
-- including the scenery flyers Wild Skies normally makes non-combatants. Since
-- 1.9 its supported shared-sky snapshot exposes every visible flyer and the
-- supported removal seam can consume an exact id. Use that only for a local,
-- revision-0 standalone sky and only for non-bold rows: shared/replay providers
-- keep their atomic claim protocol, and normal battleable flyers still go
-- through takeFlyer() first.
local function physicalSceneryFlyer(ow)
  local handle = wildSkiesHandle()
  local exports = handle and handle.exports
  local snapshot = exports and exports.sharedSkyFieldSnapshot
  local remove = exports and exports.removeSharedSkyFieldSpawn
  local p = ow and ow.player
  local mapId = ow and ow.map and ow.map.id
  if not (p and mapId and type(snapshot) == "function"
      and type(remove) == "function") then
    return nil
  end

  local okSnapshot, field = pcall(snapshot, mapId)
  if not (okSnapshot and type(field) == "table"
      and type(field.spawns) == "table") then
    return nil
  end
  -- A non-zero revision belongs to a shared provider snapshot. Never bypass
  -- its requestClaim/grantSharedSkyFieldContact ownership protocol.
  if (tonumber(field.revision) or 0) ~= 0 then return nil end

  local px = (tonumber(p.px) or ((tonumber(p.cellX) or 0) * 16)) + 8
  local py = (tonumber(p.py) or ((tonumber(p.cellY) or 0) * 16)) + 8
  local ground = terrainGroundHeight(ow.map, p.cellX, p.cellY)
  local playerAlt = math.max(0, (tonumber(flight.altitude) or 0) - ground)
  local best, bestD2

  for _, row in ipairs(field.spawns) do
    if type(row) == "table" and row.bold ~= true
       and type(row.id) == "string" and type(row.species) == "string" then
      local fx = (tonumber(row.x) or 0) + 8
      local fy = (tonumber(row.y) or 0) + 8
      local dx, dy = fx - px, fy - py
      local d2 = dx * dx + dy * dy
      local dz = math.abs((tonumber(row.alt) or playerAlt) - playerAlt)
      if d2 <= WILD_SKIES_PHYSICAL_RADIUS * WILD_SKIES_PHYSICAL_RADIUS
         and dz <= WILD_SKIES_ALTITUDE_RADIUS
         and (not bestD2 or d2 < bestD2) then
        best, bestD2 = row, d2
      end
    end
  end
  if not best then return nil end

  local okRemove, removed = pcall(remove, best.id)
  if not (okRemove and removed == true) then return nil end
  wildSkies.sceneryInterceptCount = wildSkies.sceneryInterceptCount + 1
  return {
    id = best.id,
    species = best.species,
    level = tonumber(best.level) or 5,
    altitude = tonumber(best.alt) or playerAlt,
    scenery = true,
  }
end

local function now()
  if love and love.timer and love.timer.getTime then
    return love.timer.getTime()
  end
  return os.clock()
end

local function tagOrganicDoubleBattle()
  local db = enabledModHandle("double_battles")
  local tag = db and db.exports and db.exports.tagOrganic
  if type(tag) == "function" then pcall(tag) end
end

local function configureDoubleBattlesPartnerSource()
  if wildSkies.doubleBattlesRegistered then return true end
  local db = enabledModHandle("double_battles")
  local exports = db and db.exports
  local register = exports and exports.registerPartnerSource
  if type(register) ~= "function" then return false end

  local ok, accepted = pcall(register, {
    id = DOUBLE_BATTLES_SOURCE_ID,
    priority = 40,
    provide = function(game, battle)
      local it = wildSkies.lastIntercept
      if not it or now() - (it.at or 0) > 10 then return nil end
      local enemy = battle and battle.enemy
      if not (enemy and enemy.mon and enemy.mon.species == it.species) then
        return nil
      end
      local skies = wildSkiesHandle()
      local takeFlockmate = skies and skies.exports and skies.exports.takeFlockmate
      if type(takeFlockmate) ~= "function" then return nil end
      local p = game and game.overworld and game.overworld.player
      if not p then return nil end
      local okMate, mate = pcall(takeFlockmate, p.cellX, p.cellY, 8)
      if not (okMate and mate and mate.species) then return nil end
      return mate.species, mate.level
    end,
  })
  wildSkies.doubleBattlesRegistered = ok and accepted ~= false
  return wildSkies.doubleBattlesRegistered
end

local function resetIntegrationHandles()
  wildSkies.handle = nil
  wildSkies.take = nil
  wildSkies.doubleBattlesRegistered = false
  configureWildSkiesSpriteSource()
  configureDoubleBattlesPartnerSource()
end

configureWildSkiesSpriteSource()
configureDoubleBattlesPartnerSource()
mod.events:on("mods.loaded", resetIntegrationHandles)
mod.events:on("game.ready", resetIntegrationHandles)

local function startWildSkiesBattle(ow, hit)
  if not (hit and hit.species) then return false end
  local level = tonumber(hit.level) or 5
  wildSkies.cooldown = 2
  wildSkies.battleRest = WILD_SKIES_BATTLE_REST
  wildSkies.interceptCount = wildSkies.interceptCount + 1
  wildSkies.lastIntercept = {
    species = hit.species,
    level = level,
    altitude = tonumber(hit.altitude) or flight.altitude,
    mount = flight.species,
    scenery = hit.scenery == true,
    at = now(),
  }

  pcall(function() require("src.core.Sound").playCry(Game.data, hit.species) end)
  log("intercepted Wild Skies %s Lv.%s%s",
    tostring(hit.species), tostring(level), hit.scenery and " [scenery]" or "")
  pcall(function()
    mod.events:emit("mod.dramatic_sky_ride.flyer_intercepted", {
      species = hit.species,
      level = level,
      altitude = tonumber(hit.altitude) or flight.altitude,
      mount = flight.species,
      scenery = hit.scenery == true,
    })
  end)

  tagOrganicDoubleBattle()
  local queued, err = nil, "mod.world.queueScript unavailable"
  if mod.world and mod.world.queueScript then
    queued, err = mod.world:queueScript({
      { "start_battle", "wild", hit.species, level },
    })
  end
  if queued == true then
    wildSkies.lastQueueError = nil
    return true
  end

  -- Gold's queueScript normally enters World:startBattle synchronously. If
  -- another compatibility layer rejects the per-mod queue despite the world
  -- being genuinely free-roam, use Gold's native battle entry as a last-resort
  -- handoff rather than silently deleting the flyer.
  if isGen2Runtime(Game) and ow and type(ow.startBattle) == "function" then
    local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
    local mon = okMon and Mon and Mon.new
      and Mon.new(Game.data, hit.species, level) or nil
    if mon then
      local save = Game and Game.save
      if save then
        save.pokedex = save.pokedex or { seen = {}, caught = {} }
        save.pokedex.seen[hit.species] = true
      end
      local okStart, started = pcall(ow.startBattle, ow, { wild = mon })
      if okStart and started ~= false then
        wildSkies.lastQueueError = nil
        log("Wild Skies battle used native Gold fallback")
        return true
      end
      err = okStart and "World:startBattle rejected" or started
    end
  end

  wildSkies.lastQueueError = tostring(err or "battle start rejected")
  log("Wild Skies battle start failed: %s", wildSkies.lastQueueError)
  return false
end

local function tryWildSkiesIntercept(ow)
  if not (flight.active and flight.phase == "cruise"
      and mod.exports.flightRules.airEncountersEnabled()) then
    return
  end
  local freeRoam = mod.exports and mod.exports._mountFreeRoam
  if type(freeRoam) ~= "function" then return end
  local okRoam, roam = pcall(freeRoam, Game, ow)
  if not okRoam or roam ~= true then return end
  if wildSkies.cooldown > 0 or wildSkies.battleRest > 0 then return end
  local p = ow.player
  if not p then return end

  local hit = nil
  local take = wildSkiesTakeFlyer()
  if take then
    local okTake, taken = pcall(take, p.cellX, p.cellY,
      WILD_SKIES_INTERCEPT_RADIUS)
    if okTake and taken and taken.species then hit = taken end
  end

  -- A literal DSR collision promotes Wild Skies' otherwise decorative flyers
  -- into encounters. This is deliberately second choice: bold flyers, shared
  -- provider claims and Wild Skies' own after-battle rest all get first say.
  if not hit then hit = physicalSceneryFlyer(ow) end
  if not hit then return end
  startWildSkiesBattle(ow, hit)
end

local wildSkiesUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local frameDt = tonumber(dt) or 1 / 60
  syncWildSkiesAirborneMarker(self)
  local result = wildSkiesUpdate(self, dt, ...)
  syncWildSkiesAirborneMarker(self)
  wildSkies.cooldown = math.max(0, (wildSkies.cooldown or 0) - frameDt)
  wildSkies.battleRest = math.max(0, (wildSkies.battleRest or 0) - frameDt)
  if Game.overworld == self then tryWildSkiesIntercept(self) end
  return result
end

if mod.hooks and mod.hooks.wrap then
  mod.hooks:wrap("encounter.species", function(next, encounter, ctx)
    if flight.active then return nil end
    return next(encounter, ctx)
  end, 90)
end

mod.events:on("battle.ended", function()
  wildSkies.lastIntercept = nil
end)

mod.exports.altitude = function() return flight.active and flight.altitude or 0 end
mod.exports.mount = function()
  if not (flight.active and flight.mon) then return nil end
  return { species = flight.species or flight.mon.species,
           level = flight.mon.level }
end
mod.exports.wildSkies = {
  installed = function() return wildSkiesHandle() ~= nil end,
  integrationMode = function()
    if not wildSkiesHandle() then return "absent" end
    return isGen2Runtime(Game) and "gen2" or "gen1"
  end,
  isPlayerAdvertisedAirborne = function()
    local ow = Game and Game.overworld
    local p = ow and ow.player
    return p ~= nil and p.dramaticSkyRideFreeFlying == true and p.freeFlying == true
  end,
  lastIntercept = function() return wildSkies.lastIntercept end,
  interceptCount = function() return wildSkies.interceptCount end,
  sceneryInterceptCount = function() return wildSkies.sceneryInterceptCount end,
  lastBattleStartError = function() return wildSkies.lastQueueError end,
  battleRest = function() return wildSkies.battleRest end,
  spriteSourceRegistered = function() return wildSkies.registered == true end,
  spriteIntegrationMode = function() return wildSkies.spriteMode end,
  doubleBattlesPartnerRegistered = function()
    return wildSkies.doubleBattlesRegistered == true
  end,
}

log("Wild Skies Gen1/Gen2 integration loaded")
end)()