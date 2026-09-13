;(function()
-- alpha.16 flight progression rules.
-- Keep Dramatic Sky Ride's authored mount roster, but gate actual takeoff and
-- water landing through the same progression concepts as the vanilla field
-- moves: FLY availability, THUNDERBADGE, SOULBADGE and data-driven badge gates.

local function appendOptionOnce(row)
  for _, existing in ipairs(OPTION_SCHEMA or {}) do
    if existing.key == row.key then return end
  end
  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = row
end

appendOptionOnce({
  key = "require_fly_move",
  type = "toggle",
  label = "REQUIRE FLY",
  default = true,
  help = "Require the selected mount to be allowed to use FLY before takeoff.",
})
appendOptionOnce({
  key = "badge_checks",
  type = "toggle",
  label = "BADGE CHECKS",
  default = true,
  help = "Require THUNDERBADGE for flight and SOULBADGE for water landings.",
})
appendOptionOnce({
  key = "story_gates",
  type = "toggle",
  label = "STORY GATES",
  default = true,
  help = "Respect the game's data-driven badge and event gates while flying.",
})
appendOptionOnce({
  key = "camera_altitude",
  type = "toggle",
  label = "CAMERA ALTITUDE",
  default = true,
  help = "In 1ST/3RD, looking up climbs and looking down descends.",
})
appendOptionOnce({
  key = "air_encounters",
  type = "toggle",
  label = "AIR ENCOUNTERS",
  default = true,
  help = "Allow mid-air interception of Wild Skies Pokemon when installed.",
})

for _, row in ipairs(OPTION_SCHEMA or {}) do
  if row.key == "manual_altitude" then
    row.help = "R2/Page Up climbs; L2/Page Down descends. 1ST/3RD can also follow camera pitch."
  end
end
if mod.options and mod.options.define then mod.options:define(OPTION_SCHEMA) end

local function requireFlyMoveEnabled()
  return optionValue("require_fly_move", true) == true
end
local function badgeChecksEnabled()
  return optionValue("badge_checks", true) == true
end
local function storyGatesEnabled()
  return optionValue("story_gates", true) == true
end
local function cameraAltitudeEnabled()
  return optionValue("camera_altitude", true) == true
end
local function airEncountersEnabled()
  return optionValue("air_encounters", true) == true
end

local function monKnowsMove(mon, moveId)
  for _, mv in ipairs((mon and mon.moves) or {}) do
    local id = type(mv) == "table" and mv.id or mv
    if id == moveId then return true end
  end
  return false
end

local function fieldMoveUser(ow, moveId)
  if ow and ow.partyKnows then
    local ok, user = pcall(ow.partyKnows, ow, moveId)
    if ok then return user end
  end
  return nil
end

-- A field-move eligibility mod may deliberately relax vanilla requirements.
-- In that case defer to the engine's own hook chain instead of second-guessing it.
local function canLearnFly(game, mon)
  local def = game and game.data and game.data.pokemon
    and mon and game.data.pokemon[mon.species]
  for _, moveId in ipairs((def and def.tmhm) or {}) do
    if moveId == "FLY" then return true end
  end
  return false
end

local function selectedMountCanFly(game, ow, mon)
  if not requireFlyMoveEnabled() then return true end
  if monKnowsMove(mon, "FLY") then return true end
  local okRuntime, Runtime = pcall(require, "src.mods.Runtime")
  if okRuntime and Runtime and Runtime.wantsHook
     and Runtime.wantsHook("fieldmove.eligibility")
     and canLearnFly(game, mon) then
    -- Match Free Fly's compatibility policy: if another mod relaxes field
    -- move eligibility, let the engine nominate a usable FLY user while the
    -- selected mount still has to be a species that can learn HM02.
    return fieldMoveUser(ow, "FLY") ~= nil
  end
  return false
end

local function hasBadge(game, badge)
  local bag = game and game.save and game.save.inventory or {}
  return bag and bag[badge] ~= nil and bag[badge] ~= false and bag[badge] ~= 0
end

-- Wrap the existing takeoff function late so every existing caller (party row,
-- keyboard shortcut and gamepad shortcut) automatically receives the same gate.
local startFlightWithoutProgressionRules = startFlight
startFlight = function(game, mon)
  local ow = mod.exports._mountWorld(game)
  if not (ow and mon) then return false end
  if not selectedMountCanFly(game, ow, mon) then
    say(game, "This Pokemon can't\nuse FLY yet.")
    notifyHud("FLY REQUIRED")
    feedback("blocked")
    return false
  end
  if badgeChecksEnabled() and not hasBadge(game, "THUNDERBADGE") then
    say(game, "The THUNDERBADGE\nis required to fly.")
    notifyHud("THUNDERBADGE REQUIRED")
    feedback("blocked")
    return false
  end
  return startFlightWithoutProgressionRules(game, mon)
end

-- Restore vanilla SURF progression to DSR's automatic water landing. The old
-- implementation intentionally checked only for a party SURF user; alpha.16
-- keeps that check and additionally requires SOULBADGE when badge rules are on.
local landingCellKindWithoutBadgeRules = landingCellKind
landingCellKind = function(ow, x, y)
  local kind, surfMon, reason = landingCellKindWithoutBadgeRules(ow, x, y)
  if kind == "water" and badgeChecksEnabled()
     and not hasBadge(Game, "SOULBADGE") then
    return nil, nil, "soul_badge_required"
  end
  return kind, surfMon, reason
end

-- Prefer a mount that satisfies the FLY rule when the shortcut auto-selects a
-- party member. If none does, fall back to the legacy choice so startFlight()
-- can still explain the precise blocker to the player.
local preferredMountWithoutFlightRules = preferredMount
preferredMount = function(game)
  local party = game and game.save and game.save.party or {}
  local ow = mod.exports._mountWorld(game)
  if lastMountIndex and healthy(party[lastMountIndex])
     and mountSpecies(game, party[lastMountIndex])
     and selectedMountCanFly(game, ow, party[lastMountIndex]) then
    return party[lastMountIndex]
  end
  for i, mon in ipairs(party) do
    if healthy(mon) and mountSpecies(game, mon)
       and selectedMountCanFly(game, ow, mon) then
      lastMountIndex = i
      return mon
    end
  end
  return preferredMountWithoutFlightRules(game)
end

-- Give the badge-specific explanation before the older generic landing error.
local beginLandingWithoutProgressionMessage = beginLanding
beginLanding = function(game, forced)
  local ow = mod.exports._mountWorld(game)
  local p = ow and ow.player
  if not forced and flight.active and badgeChecksEnabled()
     and p and ow.map and ow.map.isWaterCell
     and ow.map:isWaterCell(p.cellX, p.cellY)
     and not hasBadge(game, "SOULBADGE") then
    notifyHud("SOULBADGE REQUIRED")
    say(game, "The SOULBADGE is\nrequired to land here.")
    feedback("blocked")
    return false
  end
  return beginLandingWithoutProgressionMessage(game, forced)
end

-- Data-driven story barriers: use the same field.badgeGates table the game's
-- walking checkpoints use. Mods that add their own badge/event gates are
-- therefore respected automatically.
local function storyGateBlocks(mapId)
  if not storyGatesEnabled() or type(mapId) ~= "string" then return false end
  local field = Game.data and Game.data.field
  local entry = field and field.badgeGates and field.badgeGates[mapId]
  if not entry then return false end
  local save = Game.save
  local flags = (save and save.flags) or {}
  local bag = (save and save.inventory) or {}
  if flags[entry.passedFlag or ("PASSED_" .. tostring(mapId))] then
    return false
  end
  if entry.badge then return not bag[entry.badge] end
  for _, guard in ipairs(entry.guards or {}) do
    if not (flags[guard.event] or (guard.badge and bag[guard.badge])) then
      return true
    end
  end
  return false
end

if not OverworldState.dramaticSkyRideStoryGateWrapped then
  local nativeCrossConnection = OverworldState.crossConnection
  if type(nativeCrossConnection) == "function" then
    OverworldState.crossConnection = function(self, dir, conn, ...)
      if flight.active and Game.overworld == self and conn
         and storyGateBlocks(conn.mapId or conn.map) then
        if (flight.storyGateNoticeCooldown or 0) <= 0 then
          notifyHud("STORY BLOCKED")
          feedback("blocked")
          flight.storyGateNoticeCooldown = 1.0
        end
        return false
      end
      return nativeCrossConnection(self, dir, conn, ...)
    end
  end
  OverworldState.dramaticSkyRideStoryGateWrapped = true
end

-- Cooldown is updated in a tiny outer update wrapper so a held direction at a
-- blocked seam does not spam sound/HUD every frame.
local storyRuleUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  if flight.storyGateNoticeCooldown then
    flight.storyGateNoticeCooldown = math.max(0,
      flight.storyGateNoticeCooldown - (tonumber(dt) or 1 / 60))
  end
  return storyRuleUpdate(self, dt, ...)
end

mod.exports.flightRules = {
  requireFlyMove = requireFlyMoveEnabled,
  badgeChecks = badgeChecksEnabled,
  storyGates = storyGatesEnabled,
  storyGateBlocks = storyGateBlocks,
  cameraAltitudeEnabled = cameraAltitudeEnabled,
  airEncountersEnabled = airEncountersEnabled,
  canTakeOff = function(mon)
    local ow = Game.overworld
    if not (ow and mon and mountSpecies(Game, mon)) then return false end
    if not selectedMountCanFly(Game, ow, mon) then return false end
    if badgeChecksEnabled() and not hasBadge(Game, "THUNDERBADGE") then return false end
    return true
  end,
}

log("alpha.16 FLY, badge and story progression rules loaded")
end)();
