(function()
-- Gold-native Suicune traversal bridge.
--
-- Gen 1 stores Surf traversal on player.surfing. Gold instead makes the
-- movement decision from World.playerState and swaps in World:surfMap before
-- Player:tryMove. main_33 intentionally keeps the mature Gen 1 implementation;
-- this late layer translates Suicune's amphibious Ground Ride onto Gold's real
-- state machine without importing or monkey-patching src.world.gen2.Player.

local generation = mod.exports.runtimeGeneration or {}
local gen2Progression = mod.exports.gen2Progression or {}
local gen2Mounts = mod.exports.gen2Mounts or {}
local goldOwnsSurfState = false
local previousGoldPlayerState = nil

local function isGold()
  return type(generation.isGen2) == "function" and generation.isGen2(Game) == true
end

local function suicuneActive()
  if type(gen2Mounts.suicuneAmphibiousActive) == "function" then
    local ok, active = pcall(gen2Mounts.suicuneAmphibiousActive)
    if ok then return active == true end
  end
  return ground.active == true and ground.species == "SUICUNE"
end

local function waterAt(map, x, y)
  return map and type(map.inBounds) == "function" and map:inBounds(x, y)
    and type(map.isWaterCell) == "function" and map:isWaterCell(x, y) == true
end

local function badgeChecksEnabled()
  local raw = generation.rawOptionValue
  if type(raw) ~= "function" then return true end
  local ok, value = pcall(raw, "badge_checks", true)
  return not ok or value ~= false
end

-- Gold's live World owns partyMoveUser(). The Gen2Compat
-- OverworldController.partyKnows facade is intentionally a boolean query and
-- is not the live World method, so use the native shared field-move seam here.
local function goldSurfUnlocked(world)
  if not (isGold() and world and type(world.partyMoveUser) == "function") then
    return false
  end
  local okMove, mon = pcall(world.partyMoveUser, world, "SURF")
  if not (okMove and mon) then return false end

  if badgeChecksEnabled() and type(gen2Progression.hasBadge) == "function" then
    local okBadge, hasFog = pcall(gen2Progression.hasBadge, Game, "FOG")
    if not (okBadge and hasFog) then return false end
  end

  -- A normal Gold Surf start cannot originate from the bicycle state. Ground
  -- Ride normally owns movement already, but preserve the vanilla exclusion
  -- if another compatibility mod leaves that state behind.
  if world.playerState == "bike" then return false end
  return true
end

local function setGoldSurfState(world, player, enabled)
  if not (isGold() and world and player) then return end
  if enabled then
    if not goldOwnsSurfState then
      previousGoldPlayerState = world.playerState
    end
    goldOwnsSurfState = true
    world.playerState = "surf"
    player.surfing = true -- shared DSR marker used by later visual layers
    player.surfingPikachu = false
    ground.amphibiousWater = true
  else
    player.surfing = false
    ground.amphibiousWater = false
    if goldOwnsSurfState and world.playerState == "surf" then
      world.playerState = previousGoldPlayerState or "normal"
    end
    previousGoldPlayerState = nil
    goldOwnsSurfState = false
  end
end

local function connectedLandingIsWater(dir)
  if not (OverworldState and type(OverworldState.connectionLanding) == "function") then
    return false
  end
  -- The Gold facade's connectionLanding is a module-style query rather than a
  -- colon method. It returns the same five-value shape as Gen 1.
  local ok, dest, tileset, x, y = pcall(OverworldState.connectionLanding, dir)
  if not (ok and dest and tileset and x ~= nil and y ~= nil) then return false end
  return type(Map.defIsWaterCell) == "function"
    and Map.defIsWaterCell(dest, tileset, x, y) == true
end

-- Gold calls movement.collision from its real Player class. When a dry
-- Suicune step targets water, Gold has already supplied the ordinary land map
-- to Player:tryMove, so the engine's initial verdict is "tile". Promote only
-- that exact shoreline denial after arming World.playerState="surf"; pass the
-- new verdict through the rest of the hook chain so another mod can still
-- veto it. Bounds stays denied so World:movePlayer follows its normal
-- tryConnection path, but we pre-arm Surf when that connected landing is water.
mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
  if not (isGold() and suicuneActive() and ctx and ctx.mover) then
    return next(allowed, ctx)
  end

  local world = Game.overworld
  local player = world and world.player
  if not (world and player and ctx.mover == player) then
    return next(allowed, ctx)
  end

  local fromWater = waterAt(world.map, ctx.fromX, ctx.fromY)
  local toWater = waterAt(world.map, ctx.toX, ctx.toY)

  if not fromWater and toWater and world.playerState ~= "surf" then
    if not goldSurfUnlocked(world) then
      notifyHud("SURF REQUIRED", 1.4)
      return next(allowed, ctx)
    end
    setGoldSurfState(world, player, true)
    if allowed == false and ctx.reason == "tile" then
      ctx.reason = "dramatic_suicune_surf"
      return next(true, ctx)
    end
  elseif allowed == false and ctx.reason == "bounds"
      and world.playerState ~= "surf" and connectedLandingIsWater(ctx.dir) then
    if not goldSurfUnlocked(world) then
      notifyHud("SURF REQUIRED", 1.4)
      return next(allowed, ctx)
    end
    -- Keep the bounds verdict. Gold will immediately call World:tryConnection
    -- with the newly armed Surf state, preserving its native seam validation.
    setGoldSurfState(world, player, true)
  end

  return next(allowed, ctx)
end, 110)

-- main_33's recovery wrapper correctly handles Gen 1 by temporarily hiding
-- player.surfing, but its legacy progression query cannot interrogate Gold's
-- World. Intercept only the Gold-on-water case, hide both compatibility state
-- and World.playerState through the older land-only guard, then restore the
-- native Gold Surf state once the Ground Ride remount succeeds.
local previousGoldStartGroundRide = startGroundRide
startGroundRide = function(game, mon)
  if not isGold() then return previousGoldStartGroundRide(game, mon) end
  local world = mod.exports._mountWorld(game)
  local player = world and world.player
  local species = groundSpecies(game, mon)
  if species ~= "SUICUNE" or not (player and waterAt(world.map, player.cellX, player.cellY)) then
    return previousGoldStartGroundRide(game, mon)
  end
  if not goldSurfUnlocked(world) then return false end

  local oldSurfMarker = player.surfing
  local oldState = world.playerState
  player.surfing = false
  if world.playerState == "surf" then world.playerState = "normal" end
  local ok = previousGoldStartGroundRide(game, mon)
  player.surfing = oldSurfMarker
  world.playerState = oldState
  if ok then setGoldSurfState(world, player, true) end
  return ok
end

-- Synchronize after the common main_33 update. Gold itself returns to NORMAL
-- for an in-map water->land step; this also covers connection exits and keeps
-- DSR's shared p.surfing marker aligned with the actual World state.
local previousGoldSuicuneUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousGoldSuicuneUpdate(self, dt, ...)
  if not isGold() then return result end

  local world = Game.overworld
  local player = world and world.player
  if not (world and player) then return result end

  if suicuneActive() then
    local onWater = waterAt(world.map, player.cellX, player.cellY)
    if onWater and goldSurfUnlocked(world) then
      setGoldSurfState(world, player, true)
    elseif not onWater and goldOwnsSurfState then
      setGoldSurfState(world, player, false)
    end
  elseif goldOwnsSurfState and not player.surfing then
    setGoldSurfState(world, player, false)
  end
  return result
end

-- Replace only the public diagnostic/progression query. main_33 keeps its Gen 1
-- implementation private; consumers on Gold now receive the actual Gold result.
if mod.exports.gen2Mounts then
  mod.exports.gen2Mounts.surfProgressionUnlocked = function()
    return goldSurfUnlocked(Game.overworld)
  end
end

mod.exports.gen2GoldSuicune = {
  active = function() return isGold() and suicuneActive() end,
  ownsSurfState = function() return goldOwnsSurfState == true end,
  playerState = function()
    local world = Game.overworld
    return world and world.playerState or nil
  end,
  surfUnlocked = function() return goldSurfUnlocked(Game.overworld) end,
}

log("Gold-native Suicune playerState bridge loaded")
end)();
