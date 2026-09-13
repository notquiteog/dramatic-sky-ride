(function()
-- -------------------------------------------------------------------------
-- Generation II mount extension.
--
-- The roster is keyed by National Dex, not by a required content-mod id.
-- Crystal 251 (or another future content provider) supplies the actual party
-- Pokemon; Wilds of Kanto or mfrtechconsult/PokePCFollowers supplies the art.
-- -------------------------------------------------------------------------

local GEN2_FLIGHT = {
  NOCTOWL  = { dex = 164, label = "NOCTOWL",  lift = 6.4, eye = 18.0 },
  CROBAT   = { dex = 169, label = "CROBAT",   lift = 5.8, eye = 17.5 },
  XATU     = { dex = 178, label = "XATU",     lift = 6.2, eye = 18.0 },
  SKARMORY = { dex = 227, label = "SKARMORY", lift = 6.7, eye = 18.5 },
  LUGIA    = { dex = 249, label = "LUGIA",    lift = 8.0, eye = 21.0 },
  HO_OH    = { dex = 250, label = "HO-OH",    lift = 7.5, eye = 20.5 },
}

local GEN2_GROUND = {
  MEGANIUM  = { dex = 154, label = "MEGANIUM",  lift = 7.3 },
  GIRAFARIG = { dex = 203, label = "GIRAFARIG", lift = 7.2 },
  URSARING  = { dex = 217, label = "URSARING",  lift = 7.8 },
  DONPHAN   = { dex = 232, label = "DONPHAN",   lift = 6.5 },
  STANTLER  = { dex = 234, label = "STANTLER",  lift = 7.2 },
  RAIKOU    = { dex = 243, label = "RAIKOU",    lift = 7.0 },
  ENTEI     = { dex = 244, label = "ENTEI",     lift = 7.2 },
  SUICUNE   = { dex = 245, label = "SUICUNE",   lift = 7.0, amphibious = true },
  TYRANITAR = { dex = 248, label = "TYRANITAR", lift = 8.2 },
}

local GEN2_SURF_DEX = {
  FERALIGATR = 160,
  MANTINE = 226,
  KINGDRA = 230,
  LUGIA = 249,
}

-- Only values that are actually consumed by the late compatibility layer live
-- here. Stamina/acceleration retain the mature Ground Ride defaults; the
-- species-specific differentiation is speed, gallop and rider seat height.
local GEN2_GROUND_PROFILES = {
  MEGANIUM  = { base = 0.96, gallop = 1.20, lift = 7.3 },
  GIRAFARIG = { base = 1.07, gallop = 1.34, lift = 7.2 },
  URSARING  = { base = 0.88, gallop = 1.16, lift = 7.8 },
  DONPHAN   = { base = 0.98, gallop = 1.30, lift = 6.5 },
  STANTLER  = { base = 1.10, gallop = 1.40, lift = 7.2 },
  RAIKOU    = { base = 1.18, gallop = 1.50, lift = 7.0 },
  ENTEI     = { base = 1.10, gallop = 1.40, lift = 7.2 },
  SUICUNE   = { base = 1.16, gallop = 1.47, lift = 7.0 },
  TYRANITAR = { base = 0.84, gallop = 1.13, lift = 8.2 },
}

for species, cfg in pairs(GEN2_FLIGHT) do
  ELIGIBLE[species] = { dex = cfg.dex, label = cfg.label }
  ELIGIBLE_BY_DEX[cfg.dex] = species
  RIDER_OFFSETS[species] = {
    lift = cfg.lift,
    depth = 0.35,
    orbitX = 0.0,
    orbitY = 0.35,
    eye = cfg.eye,
  }
end

for species, cfg in pairs(GEN2_GROUND) do
  GROUND_ELIGIBLE[species] = { dex = cfg.dex, label = cfg.label, lift = cfg.lift }
  GROUND_BY_DEX[cfg.dex] = species
end

-- main_21 reads mount_size_<species> dynamically. Its private list only
-- publishes rows, so publish the Johto rows here without changing Gen 1.
local GEN2_SIZE_SPECIES = {
  "NOCTOWL", "CROBAT", "XATU", "SKARMORY", "LUGIA", "HO_OH",
  "MEGANIUM", "GIRAFARIG", "URSARING", "DONPHAN", "STANTLER",
  "RAIKOU", "ENTEI", "SUICUNE", "TYRANITAR",
  "FERALIGATR", "MANTINE", "KINGDRA",
}
for _, species in ipairs(GEN2_SIZE_SPECIES) do
  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = {
    key = "mount_size_" .. species:lower(),
    type = "number",
    label = "SIZE " .. species:gsub("_", "-"),
    default = 100,
    min = 50,
    max = 200,
    step = 5,
    help = "100 keeps this Gen 2 mount at its Pokedex-derived size.",
  }
end
if mod.options and mod.options.define then mod.options:define(OPTION_SCHEMA) end

-- -------------------------------------------------------------------------
-- Provider-safe Gen 2 sprite resolution.
--
-- Try the canonical species id first, then its National Dex. The numeric
-- retry is important for providers whose local name normalization differs
-- (for example punctuation in Ho-Oh) while keeping Wilds/PokePC interchangeable.
-- -------------------------------------------------------------------------
local GEN2_PROVIDER_IDS = {
  "overworld_wild_spawns",
  "PokePCFollowers_VoxelMerge",
  "pokepcfollowers",
  "FOLLOWERS_EX",
  "followers_ex",
}

local function providerImage(species, dex, role)
  if not mod.find then return nil end
  local identities = { species, dex }
  for _, providerId in ipairs(GEN2_PROVIDER_IDS) do
    local okFind, handle = pcall(mod.find, mod, providerId)
    local ex = okFind and handle and handle.exports or nil
    if ex and type(ex.resolveFollowerSprite) == "function" then
      for _, identity in ipairs(identities) do
        local okDef, def = pcall(ex.resolveFollowerSprite, {
          species = identity,
          dex = dex,
          surface = "land",
          style = providerId == "overworld_wild_spawns" and "followers" or nil,
          role = role,
          game = Game,
        })
        local frames = def and tonumber(def.frames) or 0
        if okDef and def and def.image and frames >= 6 then
          local okImage, image = pcall(Assets.image, def.image)
          if okImage and image then
            local w, h = image:getDimensions()
            if w >= 16 and h >= 96 then return def.image end
          end
        end
      end
    end
    -- PokePCFollowers 0.8 publishes its canonical asset resolver directly
    -- instead of the Wilds-style descriptor resolver. Accept that stable API
    -- and validate the returned six-frame walker sheet exactly as above.
    if ex and type(ex.assetPath) == "function" then
      for _, identity in ipairs(identities) do
        local okPath, path = pcall(ex.assetPath, identity)
        if okPath and type(path) == "string" and path ~= "" then
          local okImage, image = pcall(Assets.image, path)
          if okImage and image then
            local w, h = image:getDimensions()
            if w >= 16 and h >= 96 then return path end
          end
        end
      end
    end
  end
  return nil
end

local previousFlightFollowerPathGen2 = followerPath
followerPath = function(species)
  local cfg = GEN2_FLIGHT[species]
  if cfg then
    return providerImage(species, cfg.dex, "flight_mount")
      or previousFlightFollowerPathGen2(species)
  end
  return previousFlightFollowerPathGen2(species)
end

local previousGroundFollowerPathGen2 = groundFollowerPath
groundFollowerPath = function(species)
  local cfg = GEN2_GROUND[species]
  if cfg then
    return providerImage(species, cfg.dex, "ground_mount")
      or previousGroundFollowerPathGen2(species)
  end
  return previousGroundFollowerPathGen2(species)
end

-- -------------------------------------------------------------------------
-- Gen 2 Ground Ride speed/seat profiles.
-- -------------------------------------------------------------------------
local TAUROS_PROFILE = { base = 1.06, gallop = 1.39 }
local function profileMotion(profile, blend)
  blend = tonumber(blend) or 0
  return profile.base * (1 + (profile.gallop - 1) * blend)
end

-- Existing alpha.15 code uses Tauros as the fallback profile for unknown
-- species. Correct that final multiplier only for the curated Gen 2 roster.
mod.hooks:wrap("movement.speed", function(next, frames, ctx)
  local value = next(frames, ctx)
  local profile = ground.active and GEN2_GROUND_PROFILES[ground.species] or nil
  if not profile then return value end
  local fallback = profileMotion(TAUROS_PROFILE, ground.speedBlend)
  local wanted = profileMotion(profile, ground.speedBlend)
  if wanted <= 0 then return value end
  return math.max(3, (tonumber(value) or tonumber(frames) or 8) * fallback / wanted)
end, 99)

-- Dramatic FreeMove bypasses movement.speed, so compensate the already-loaded
-- Tauros fallback for one free-camera tick and restore the provider constants.
if dramaticFreeMove and type(dramaticFreeMove.tick) == "function"
   and not dramaticFreeMove.dramaticGen2GroundSpeedHook then
  local previousTick = dramaticFreeMove.tick
  dramaticFreeMove.tick = function(state)
    local profile = ground.active and GEN2_GROUND_PROFILES[ground.species] or nil
    if not (profile and isFreeCamera()) then return previousTick(state) end
    local ratio = profileMotion(profile, ground.speedBlend)
      / profileMotion(TAUROS_PROFILE, ground.speedBlend)
    local oldWalk, oldBike = dramaticFreeMove.WALK, dramaticFreeMove.BIKE
    if tonumber(oldWalk) then dramaticFreeMove.WALK = oldWalk * ratio end
    if tonumber(oldBike) then dramaticFreeMove.BIKE = oldBike * ratio end
    local ok, result = pcall(previousTick, state)
    dramaticFreeMove.WALK, dramaticFreeMove.BIKE = oldWalk, oldBike
    if not ok then error(result, 0) end
    return result
  end
  dramaticFreeMove.dramaticGen2GroundSpeedHook = true
end

local previousGroundRiderPoseGen2 = groundRiderPose
groundRiderPose = function(entity)
  local sprite, px, py, facing, phase, flip, hopping = previousGroundRiderPoseGen2(entity)
  local profile = ground.active and GEN2_GROUND_PROFILES[ground.species] or nil
  if profile then
    local scale = 1
    if mod.exports and type(mod.exports.mountVisualScale) == "function" then
      local ok, value = pcall(mod.exports.mountVisualScale, ground.species)
      if ok and tonumber(value) then scale = tonumber(value) end
    end
    py = py - ((profile.lift or 6.5) - 6.5) * scale
  end
  return sprite, px, py, facing, phase, flip, hopping
end

-- -------------------------------------------------------------------------
-- Suicune: the only seamless land <-> water Ground Ride.
-- -------------------------------------------------------------------------
local SUICUNE = "SUICUNE"
local SUICUNE_DEX = 245
local suicuneBattleWaterResume = false

local function suicuneRideActive()
  return ground.active == true and ground.species == SUICUNE
end

-- partyKnows("SURF") is the engine's field-move gate and includes the normal
-- Soul Badge requirement. Preserve the additional vanilla Surf restrictions.
local function surfProgressionUnlocked(ow)
  if not (ow and type(ow.partyKnows) == "function") then return false end
  local ok, mon = pcall(ow.partyKnows, ow, "SURF")
  if not (ok and mon) then return false end
  if Game.save and Game.save.forcedBike then return false end
  if type(ow.surfBlockedHere) == "function" then
    local okBlocked, blocked = pcall(ow.surfBlockedHere, ow)
    if okBlocked and blocked then return false end
  end
  return true
end

local function currentCellIsWater(map, player)
  return map and player and map.inBounds and map:inBounds(player.cellX, player.cellY)
    and map.isWaterCell and map:isWaterCell(player.cellX, player.cellY) == true
end

local function setSuicuneWaterState(player, enabled)
  if not player then return end
  ground.amphibiousWater = enabled == true
  player.surfing = enabled == true
  if enabled then player.surfingPikachu = false end
end

local function targetWaterInMap(map, player, dir)
  if not (map and player and map.inBounds and map.isWaterCell) then return false end
  local tx, ty = Collision.target(player.cellX, player.cellY, dir)
  return map:inBounds(tx, ty) and map:isWaterCell(tx, ty) == true
end

-- Arm native Surf collision BEFORE Collision.canMove. We never flip a rejected
-- movement.collision verdict afterwards, so water tile-pairs and other mods'
-- collision wrappers remain authoritative.
local gen2TryMove = Player.tryMove
function Player:tryMove(dir, map, entities)
  local ow = Game.overworld
  if not (suicuneRideActive() and ow and ow.player == self) then
    return gen2TryMove(self, dir, map, entities)
  end

  -- Turning remains a normal turn. Arm water only on the subsequent real step.
  local attemptingStep = not self.moving and not self.inputLocked
    and self.facing == dir and (tonumber(self.turnTimer) or 0) <= 0
  local enteringWater = attemptingStep and not self.surfing
    and targetWaterInMap(map, self, dir)

  if enteringWater then
    if not surfProgressionUnlocked(ow) then
      notifyHud("SURF REQUIRED", 1.4)
      return gen2TryMove(self, dir, map, entities)
    end
    setSuicuneWaterState(self, true)
  end

  local result, why = gen2TryMove(self, dir, map, entities)
  if enteringWater and result ~= "moved" and not currentCellIsWater(map, self) then
    setSuicuneWaterState(self, false)
  end
  return result, why
end

-- Edge connections bypass Player:tryMove. Pre-arm the same Surf traversal
-- state when the connected landing cell is water, then let the engine's own
-- Map.defPassable/crossConnection path decide whether the seam is valid.
local gen2CheckEdgeExit = OverworldState.checkEdgeExit
function OverworldState:checkEdgeExit(dir)
  if not (suicuneRideActive() and Game.overworld == self and self.player) then
    return gen2CheckEdgeExit(self, dir)
  end

  local p = self.player
  local tx, ty = Collision.target(p.cellX, p.cellY, dir)
  if self.map and self.map.inBounds and self.map:inBounds(tx, ty) then
    return gen2CheckEdgeExit(self, dir)
  end

  local dest, ts, x, y = self:connectionLanding(dir)
  local enteringWater = dest and ts and Map.defIsWaterCell
    and Map.defIsWaterCell(dest, ts, x, y) == true
  local armed = false
  if enteringWater and not p.surfing then
    if not surfProgressionUnlocked(self) then
      notifyHud("SURF REQUIRED", 1.4)
      return gen2CheckEdgeExit(self, dir)
    end
    setSuicuneWaterState(p, true)
    armed = true
  end

  local crossed = gen2CheckEdgeExit(self, dir)
  if armed and not crossed and not currentCellIsWater(self.map, p) then
    setSuicuneWaterState(p, false)
  end
  return crossed
end

-- The separate Visible Surf subsystem must never become Suicune's visual
-- owner. p.surfing is traversal state only; ground.active remains continuous.
-- Synchronize only after a step settles so land<->water interpolation never
-- tears the rider/mount lifecycle in the middle of a movement animation.
local gen2Update = OverworldState.update
function OverworldState:update(dt, ...)
  local pBefore = self.player
  local maskSurfForBattleResume = suicuneBattleWaterResume
    and not ground.active and Game.overworld == self and pBefore
    and pBefore.surfing and currentCellIsWater(self.map, pBefore)

  -- main_19's mature battle-remount path predates amphibious mounts and skips
  -- every surfing player. Hide only that flag for this one inner update; the
  -- wrapped startGroundRide below rebuilds Suicune and we restore water state.
  if maskSurfForBattleResume then pBefore.surfing = false end
  local result = gen2Update(self, dt, ...)
  local p = self.player

  if maskSurfForBattleResume and p then
    if ground.active and ground.species == SUICUNE then
      setSuicuneWaterState(p, true)
      suicuneBattleWaterResume = false
    else
      p.surfing = true
      local pending = mod.exports and mod.exports.pendingGroundRemount
      if type(pending) == "function" then
        local okPending, stillPending = pcall(pending)
        if okPending and not stillPending then suicuneBattleWaterResume = false end
      end
    end
  end

  if suicuneRideActive() and Game.overworld == self and p and not p.moving then
    local waterHere = currentCellIsWater(self.map, p)
    if waterHere and surfProgressionUnlocked(self) then
      setSuicuneWaterState(p, true)
    elseif not waterHere and ground.amphibiousWater then
      setSuicuneWaterState(p, false)
    end
  elseif ground.amphibiousWater and not suicuneRideActive() then
    ground.amphibiousWater = false
  end
  return result
end

-- Capture exactly one exceptional battle-resume case. Every other Ground Ride
-- keeps its existing battle lifecycle unchanged.
local gen2StopGroundRide = stopGroundRide
stopGroundRide = function(game, reason, keepFollowers)
  if reason == "battle" and suicuneRideActive() and ground.amphibiousWater == true then
    suicuneBattleWaterResume = true
  end
  return gen2StopGroundRide(game, reason, keepFollowers)
end

mod.events:on("battle.ended", function(ev)
  if suicuneBattleWaterResume and ev and ev.result == "lose" then
    suicuneBattleWaterResume = false
  end
end)

-- Recovery path for a Suicune remount while the player is already on a water
-- cell. Temporarily clear native Surf only through the old land-only guard.
local gen2StartGroundRide = startGroundRide
startGroundRide = function(game, mon)
  local ow = mod.exports._mountWorld(game)
  local p = ow and ow.player
  local species = groundSpecies(game, mon)
  if species ~= SUICUNE
     or not (p and p.surfing and currentCellIsWater(ow and ow.map, p)) then
    return gen2StartGroundRide(game, mon)
  end
  if not surfProgressionUnlocked(ow) then return false end
  p.surfing = false
  local ok = gen2StartGroundRide(game, mon)
  p.surfing = true
  if ok then ground.amphibiousWater = true end
  return ok
end

mod.exports.gen2Mounts = {
  flight = GEN2_FLIGHT,
  ground = GEN2_GROUND,
  surfDex = GEN2_SURF_DEX,
  suicuneDex = SUICUNE_DEX,
  suicuneAmphibiousActive = suicuneRideActive,
  suicuneOnWater = function()
    return suicuneRideActive() and ground.amphibiousWater == true
  end,
  surfProgressionUnlocked = function()
    return surfProgressionUnlocked(Game.overworld)
  end,
  battleWaterResumePending = function()
    return suicuneBattleWaterResume == true
  end,
}

log("Generation II mounts loaded; Suicune seamless land/water ride enabled")
end)();
