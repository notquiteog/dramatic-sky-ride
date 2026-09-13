;(function()
-- Gold / Gen 2 field-move progression for Dramatic Sky Ride.
--
-- main_21b suppresses main_22's Kanto-specific checks only while Gold is
-- active. This layer reapplies the same user-facing DSR settings against the
-- actual Gold save model: STORMBADGE for FLY and FOGBADGE for SURF.

local generation = mod.exports.runtimeGeneration or {}
local isGen2Runtime = generation.isGen2 or function() return false end
local rawOptionValue = generation.rawOptionValue or optionValue

local JOHTO_BADGES = {
  "ZEPHYR", "HIVE", "PLAIN", "FOG",
  "MINERAL", "STORM", "GLACIER", "RISING",
}

local function settingEnabled(key, default)
  return rawOptionValue(key, default) == true
end

local function hasGen2Badge(game, badge)
  local owned = game and game.save and game.save.player
    and game.save.player.badges
  if type(owned) ~= "table" then return false end
  if owned[badge] == true then return true end
  for index, name in ipairs(JOHTO_BADGES) do
    if name == badge then return owned[index] == true end
  end
  return false
end

local function monKnowsMoveGen2(mon, moveId)
  for _, move in ipairs((mon and mon.moves) or {}) do
    local id = type(move) == "table" and move.id or move
    if id == moveId then return true end
  end
  return false
end

local function goldCanUseSelectedFlyMount(game, mon)
  if not settingEnabled("require_fly_move", true) then return true end
  if monKnowsMoveGen2(mon, "FLY") then return true end

  -- Keep compatibility with mods that deliberately relax field-move
  -- eligibility. Gold and Gen 1 share the same hook name and signature.
  local okRuntime, Runtime = pcall(require, "src.mods.Runtime")
  if okRuntime and Runtime and Runtime.wantsHook
     and Runtime.wantsHook("fieldmove.eligibility") then
    local world = mod.exports._mountWorld(game)
    if world and type(world.partyKnows) == "function" then
      local ok, user = pcall(world.partyKnows, world, "FLY")
      return ok and user ~= nil
    end
  end
  return false
end

-- Reapply FLY progression after main_22. Its Kanto badge and learnset checks
-- are disabled on Gold by main_21b, so this is the sole Gold-specific gate.
local startFlightAfterGen1Rules = startFlight
startFlight = function(game, mon)
  if isGen2Runtime(game) then
    if not goldCanUseSelectedFlyMount(game, mon) then
      say(game, "This Pokemon can't\nuse FLY yet.")
      notifyHud("FLY REQUIRED")
      feedback("blocked")
      return false
    end
    if settingEnabled("badge_checks", true)
       and not hasGen2Badge(game, "STORM") then
      say(game, "The STORM BADGE is\nrequired to fly.")
      notifyHud("STORM BADGE REQUIRED")
      feedback("blocked")
      return false
    end
  end
  return startFlightAfterGen1Rules(game, mon)
end

-- Gold uses FOGBADGE for SURF. Keep main_22's water-landing implementation,
-- but stop the automatic transition before it reaches the Gen 1 SOULBADGE
-- logic (which main_21b disabled on Gold).
local beginLandingAfterGen1Rules = beginLanding
beginLanding = function(game, forced)
  if isGen2Runtime(game) and not forced and flight.active
     and settingEnabled("badge_checks", true) then
    local world = mod.exports._mountWorld(game)
    local player = world and world.player
    local map = world and world.map
    local onWater = player and map and type(map.isWaterCell) == "function"
      and map:isWaterCell(player.cellX, player.cellY) == true
    if onWater and not hasGen2Badge(game, "FOG") then
      notifyHud("FOG BADGE REQUIRED")
      say(game, "The FOG BADGE is\nrequired to surf.")
      feedback("blocked")
      return false
    end
  end
  return beginLandingAfterGen1Rules(game, forced)
end

mod.exports.gen2Progression = {
  hasBadge = hasGen2Badge,
  canUseFly = goldCanUseSelectedFlyMount,
  flyBadge = "STORM",
  surfBadge = "FOG",
}

log("Gen1Recomp++ Gold FLY/SURF progression loaded")
end)();
