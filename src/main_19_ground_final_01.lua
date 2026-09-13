
;(function()

-- Alpha.15 Lot 1: Ground Ride finalisation.
-- This module deliberately touches only terrestrial riding. Flight, camera,
-- Surf rendering and the MOUNTS screen keep the validated alpha.15 behaviour.
local Sound = require("src.core.Sound")

local function lot1Option(key, default)
  local ok, value = pcall(optionValue, key, default)
  if ok and value ~= nil then return value end
  return default
end

-- Do not call mod.options:define() again here: the API replaces the complete
-- schema on each call. Automatic dismount for incompatible actions is a
-- fixed safety behaviour in Lot 1, while the existing alpha.15 options stay
-- exactly intact.

-- ---------------------------------------------------------------------------
-- Preferred mount persistence and party identity
-- ---------------------------------------------------------------------------

local function saveGet(key, default)
  if not (mod.save and mod.save.get) then return default end
  local ok, value = pcall(mod.save.get, mod.save, key, default)
  if ok and value ~= nil then return value end
  return default
end

local function saveSet(key, value)
  if not (mod.save and mod.save.set) then return end
  pcall(mod.save.set, mod.save, key, value)
end

local function partyIndexOf(game, wanted)
  for i, mon in ipairs(game and game.save and game.save.party or {}) do
    if mon == wanted then return i end
  end
  return nil
end

local function rememberGroundMount(game, mon)
  local index = partyIndexOf(game, mon)
  local species = groundSpecies(game, mon)
  if index then
    lastGroundMountIndex = index
    saveSet("preferredGroundIndex", index)
  end
  if species then saveSet("preferredGroundSpecies", species) end
end

local savedGroundIndex = tonumber(saveGet("preferredGroundIndex", nil))
if savedGroundIndex then lastGroundMountIndex = savedGroundIndex end

local lot1PreferredGroundMount = preferredGroundMount
preferredGroundMount = function(game)
  local party = game and game.save and game.save.party or {}
  local preferredIndex = tonumber(saveGet("preferredGroundIndex", lastGroundMountIndex))
  local preferredSpecies = saveGet("preferredGroundSpecies", nil)

  local atIndex = preferredIndex and party[preferredIndex]
  local atIndexSpecies = groundSpecies(game, atIndex)
  if healthy(atIndex) and atIndexSpecies
     and (not preferredSpecies or atIndexSpecies == preferredSpecies) then
    lastGroundMountIndex = preferredIndex
    return atIndex
  end

  if preferredSpecies then
    for i, mon in ipairs(party) do
      if healthy(mon) and groundSpecies(game, mon) == preferredSpecies then
        lastGroundMountIndex = i
        saveSet("preferredGroundIndex", i)
        return mon
      end
    end
  end

  return lot1PreferredGroundMount(game)
end

local lot1StartGroundRide = startGroundRide
startGroundRide = function(game, mon)
  local ok = lot1StartGroundRide(game, mon)
  if ok and ground.active then rememberGroundMount(game, ground.mon or mon) end
  return ok
end

-- ---------------------------------------------------------------------------
-- Battle/evolution/party-change restoration
-- ---------------------------------------------------------------------------

local battleResume = nil

local function mountSnapshot(game, mon)
  if not mon then return nil end
  return {
    object = mon,
    index = partyIndexOf(game, mon),
    species = groundSpecies(game, mon),
    nickname = mon.nickname,
    level = mon.level,
    stamina = tonumber(ground.stamina) or 1,
  }
end

local function resolveSnapshot(game, snap)
  if not (game and snap) then return nil end
  local party = game.save and game.save.party or {}

  -- Evolution normally mutates the same party object. This is the strongest
  -- identity and naturally follows RHYHORN -> RHYDON.
  for i, mon in ipairs(party) do
    if mon == snap.object then
      snap.index = i
      return mon
    end
  end

  -- Some menu/mod flows replace a party record rather than mutating it.
  local slotted = snap.index and party[snap.index]
  if slotted and groundSpecies(game, slotted) then return slotted end

  -- Party reordering keeps the same nickname/species combination in almost
  -- every practical case. Prefer that before falling back to species alone.
  if snap.nickname and snap.nickname ~= "" then
    for _, mon in ipairs(party) do
      if mon.nickname == snap.nickname and groundSpecies(game, mon) then
        return mon
      end
    end
  end

  if snap.species then
    for _, mon in ipairs(party) do
      if groundSpecies(game, mon) == snap.species then return mon end
    end
  end
  return nil
end

local lot1StopGroundRide = stopGroundRide
stopGroundRide = function(game, reason, keepFollowers)
  local snapshot
  if ground.active and reason == "battle" then
    snapshot = mountSnapshot(game, ground.mon)
  end
  local result = lot1StopGroundRide(game, reason, keepFollowers)
  if reason == "battle" then
    battleResume = snapshot
    -- Disable alpha.14's raw object-only resume. Lot 1 resolves the live
    -- party after battle and after any evolution screen has finished.
    ground.resumeAfterBattle = nil
  end
  return result
end

mod.events:on("battle.ended", function(ev)
  if battleResume then
    battleResume.ended = true
    battleResume.result = ev and ev.result
  end
end)

local function clearBattleResume()
  battleResume = nil
end

local function tryBattleRemount(self)
  if not battleResume or not battleResume.ended then return end
  if battleResume.result == "lose" then
    clearBattleResume()
    return
  end
  if lot1Option("remount_after_battle", true) ~= true then
    clearBattleResume()
    return
  end
  -- Gen 1 puts the overworld state on top of the stack; Gold represents free
  -- roam with an empty stack and exposes the live World through the facade.
  -- The shared capability check handles both shapes and also waits out any
  -- evolution/dialogue screen before rebuilding the mount.
  if not mod.exports._mountFreeRoam(Game, self) then return end
  if self.transitioning or self.runner and self.runner:isRunning() then return end

  local snap = battleResume
  clearBattleResume()
  local mon = resolveSnapshot(Game, snap)
  if not mon or not healthy(mon) or not groundSpecies(Game, mon) then
    notifyHud("MOUNT UNAVAILABLE", 1.8)
    return
  end
  if not groundAreaAllowed(self) or self.player.surfing then return end

  if startGroundRide(Game, mon) then
    ground.stamina = math.max(0, math.min(1, tonumber(snap.stamina) or 1))
    ground.speedBlend = 0
    ground.gallop = false
  end
end

local function activeMountStillValid(game)
  if not ground.active then return true end
  local party = game and game.save and game.save.party or {}
  for i, mon in ipairs(party) do
    if mon == ground.mon then
