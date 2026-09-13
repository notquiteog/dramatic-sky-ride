(function()
-- Follow-up runtime fixes from in-game Wilds testing.
--
-- * Keep Wilds trailer entities alive when mounted followers are enabled.
--   Removing a trailer from ow.entities/ow.npcs makes Wilds rebuild the whole
--   pack at the player, which looks like every follower is superimposed.
--   Instead, only the active mount is hidden visually while the authoritative
--   Wilds runtime keeps its normal trail state and movement cadence.
-- * FreeMove (1ST/3RD) bypasses Player.tryMove, so pre-arm Suicune's native
--   Surf traversal immediately before the free body reaches a water cell.
-- * Preserve Suicune's mount pose across the battle snapshot and the first
--   post-battle overworld frames so neither Red's stock Surf sprite nor the
--   generic visible-Surf mount can flash between Ground Ride states.

local function mountedFollowersEnabled()
  return optionValue("show_followers_while_mounted", false) == true
end

local function currentCellWater(ow, player)
  local map = ow and ow.map
  return map and player and map.inBounds and map.isWaterCell
    and map:inBounds(player.cellX, player.cellY)
    and map:isWaterCell(player.cellX, player.cellY) == true
end

local function mountedNow()
  local ow = Game.overworld
  local surfing = ow and ow.player and ow.player.surfing == true
  local waterRide = false
  if mod.exports and type(mod.exports.isWaterRiding) == "function" then
    local ok, active = pcall(mod.exports.isWaterRiding)
    waterRide = ok and active == true
  end
  return flight.active == true
      or (ground and ground.active == true)
      or waterRide
      or surfing
end

local function canonicalSpecies(value)
  if value == nil then return nil end
  return tostring(value):upper():gsub("[^A-Z0-9]", "")
end

local function mountIdentity()
  if flight.active then return flight.species, flight.mon end
  if ground and ground.active then return ground.species, ground.mon end
  if mod.exports and type(mod.exports.isWaterRiding) == "function" then
    local okRide, active = pcall(mod.exports.isWaterRiding)
    if okRide and active == true and type(mod.exports.waterMountSpecies) == "function" then
      local okSpecies, species = pcall(mod.exports.waterMountSpecies)
      if okSpecies then return species, nil end
    end
  end
  return nil, nil
end

local function isFollowerEntity(entity, player)
  if not entity or entity == player then return false end
  local spriteDef = entity.sprite and entity.sprite.def
  local defId = spriteDef and spriteDef.id
  local id = tostring(entity.id or ""):lower()
  local spriteId = tostring(entity.spriteId or defId or ""):upper()
  return entity.wildsFollower == true
      or entity.pikachuFollower == true
      or entity.isPokemonFollower == true
      or entity.pokepcTrailer == true
      or entity.pokepcMon ~= nil
      or entity._wildsFollowerSpecies ~= nil
      or entity._pokepcFollowerSpecies ~= nil
      or entity.pokepcFollowerSpecies ~= nil
      or id == "pikachu"
      or id:find("pokepc", 1, true) ~= nil
      or spriteId == "SPRITE_PIKACHU"
      or spriteId:find("POKEPC", 1, true) ~= nil
      or spriteId:find("WILDS_FOLLOWER", 1, true) ~= nil
end

local function followerSpecies(entity)
  if type(entity) ~= "table" then return nil end
  if type(entity.pokepcMon) == "table" and entity.pokepcMon.species then
    return entity.pokepcMon.species
  end
  return entity._wildsFollowerSpecies
      or entity._pokepcFollowerSpecies
      or entity.pokepcFollowerSpecies
      or entity.followerSpecies
      or (entity.wildsFollower == true and entity.species or nil)
end

local function isActiveMountFollower(entity, species, mon)
  if mon and type(entity) == "table" and entity.pokepcMon ~= nil then
    -- Wilds trailers retain the actual party object, so exact identity avoids
    -- hiding a second follower of the same species.
    return entity.pokepcMon == mon
  end
  local follower = canonicalSpecies(followerSpecies(entity))
  local mounted = canonicalSpecies(species)
  return follower ~= nil and mounted ~= nil and follower == mounted
end

-- Non-destructive visibility override. Wilds still sees every trailer in its
-- own tables, so syncTrailers never enters the dirty/reseed-at-player path.
local hiddenFollowerDraw = setmetatable({}, { __mode = "k" })

local function hideFollowerDraw(entity)
  if not entity or hiddenFollowerDraw[entity] then return end
  local draw = entity.draw
  if type(draw) ~= "function" then return end
  hiddenFollowerDraw[entity] = draw
  entity.draw = function() end
end

local function showFollowerDraw(entity)
  local draw = entity and hiddenFollowerDraw[entity]
  if not draw then return end
  entity.draw = draw
  hiddenFollowerDraw[entity] = nil
end

local function restoreFollowerDraws()
  for entity in pairs(hiddenFollowerDraw) do
    showFollowerDraw(entity)
  end
end

local function applyFollowerDrawPolicy(ow)
  if not ow then return end
  local species, mon = mountIdentity()
  local seen = setmetatable({}, { __mode = "k" })

  local function visit(list)
    for _, entity in ipairs(list or {}) do
      if not seen[entity] and isFollowerEntity(entity, ow.player) then
        seen[entity] = true
        if isActiveMountFollower(entity, species, mon) then
          hideFollowerDraw(entity)
        else
          showFollowerDraw(entity)
        end
      end
    end
  end

  visit(ow.entities)
  visit(ow.npcs)

  -- Anything no longer in the live follower lists must not retain our draw
  -- override if another runtime reuses that entity later.
  for entity in pairs(hiddenFollowerDraw) do
    if not seen[entity] then showFollowerDraw(entity) end
  end
end

-- When followers are explicitly enabled, do not tear down their runtime at
-- mount start. This is the key difference from the default hidden policy.
local previousSuspendFollowers = suspendFollowers
suspendFollowers = function(ow)
  if mountedFollowersEnabled() then
    return { entities = {}, npcs = {}, mountedFollowerPassthrough = true }
  end
  return previousSuspendFollowers(ow)
end

local previousPurgeFollowers = purgeFollowersDuringFlight
purgeFollowersDuringFlight = function(ow, captured)
  if not mountedFollowersEnabled() then
    restoreFollowerDraws()
    return previousPurgeFollowers(ow, captured)
  end
  if not (ow and mountedNow()) then
    restoreFollowerDraws()
    return captured
  end
  applyFollowerDrawPolicy(ow)
  return captured or { entities = {}, npcs = {}, mountedFollowerPassthrough = true }
end

local previousRestoreFollowers = restoreFollowers
restoreFollowers = function(ow)
  restoreFollowerDraws()
  return previousRestoreFollowers(ow)
end

-- -------------------------------------------------------------------------
-- Suicune free-camera land -> water traversal.
-- -------------------------------------------------------------------------
local function suicuneRideActive()
  return ground and ground.active == true and ground.species == "SUICUNE"
end

local function suicuneSurfUnlocked()
  local gen2 = mod.exports and mod.exports.gen2Mounts
  local fn = gen2 and gen2.surfProgressionUnlocked
  if type(fn) ~= "function" then return false end
  local ok, unlocked = pcall(fn)
  return ok and unlocked == true
end

local function mapWater(map, x, y)
  if not (map and map.inBounds and map.isWaterCell and map:inBounds(x, y)) then
    return false
  end
  local ok, water = pcall(map.isWaterCell, map, x, y)
  return ok and water == true
end

local function freeMoveApproachesWater(state)
  local p = state and state.player
  local map = state and state.map
  if not (p and map and suicuneRideActive() and not p.surfing and isFreeCamera()) then
    return false
  end

  dramaticFirstPerson = dramaticFirstPerson or dramaticModule("FirstPerson")
  local fp = dramaticFirstPerson
  if not (fp and type(fp.moveVector) == "function" and type(fp.moveWorld) == "function") then
    return false
  end

  local okMove, mx, mz = pcall(fp.moveVector)
  if not okMove then return false end
  local okWorld, wx, wz = pcall(fp.moveWorld, mx or 0, mz or 0)
  if not okWorld then return false end
  wx, wz = tonumber(wx) or 0, tonumber(wz) or 0
  if math.abs(wx) < 0.01 and math.abs(wz) < 0.01 then return false end

  local pos
  if dramaticFreeMove and type(dramaticFreeMove._pos) == "function" then
    local okPos, value = pcall(dramaticFreeMove._pos)
    if okPos and type(value) == "table" then pos = value end
  end
  local px = tonumber(pos and pos.x) or ((tonumber(p.px) or p.cellX * 16) + 8)
  local pz = tonumber(pos and pos.z) or ((tonumber(p.py) or p.cellY * 16) + 8)
  local radius = tonumber(dramaticFreeMove and dramaticFreeMove.RADIUS) or 5.5
  -- Ground Ride at the maximum user speed still advances only a few world
  -- pixels per logic tick. Looking one small step ahead is enough to arm Surf
  -- before FreeMove's body-overlap collision checks touch the water cell.
  local margin = 4.5
  local eps = 0.01

  if wx > 0.01 then
    local edgeX = math.floor((px + radius + margin) / 16)
    if edgeX > p.cellX then
      local z0 = math.floor((pz - radius + eps) / 16)
      local z1 = math.floor((pz + radius - eps) / 16)
      for z = z0, z1 do if mapWater(map, edgeX, z) then return true end end
    end
  elseif wx < -0.01 then
    local edgeX = math.floor((px - radius - margin) / 16)
    if edgeX < p.cellX then
      local z0 = math.floor((pz - radius + eps) / 16)
      local z1 = math.floor((pz + radius - eps) / 16)
      for z = z0, z1 do if mapWater(map, edgeX, z) then return true end end
    end
  end

  if wz > 0.01 then
    local edgeY = math.floor((pz + radius + margin) / 16)
    if edgeY > p.cellY then
      local x0 = math.floor((px - radius + eps) / 16)
      local x1 = math.floor((px + radius - eps) / 16)
      for x = x0, x1 do if mapWater(map, x, edgeY) then return true end end
    end
  elseif wz < -0.01 then
    local edgeY = math.floor((pz - radius - margin) / 16)
    if edgeY < p.cellY then
      local x0 = math.floor((px - radius + eps) / 16)
      local x1 = math.floor((px + radius - eps) / 16)
      for x = x0, x1 do if mapWater(map, x, edgeY) then return true end end
    end
  end

  return false
end

if dramaticFreeMove and type(dramaticFreeMove.tick) == "function"
   and not dramaticFreeMove.dramaticSuicuneWaterHook then
  local previousFreeMoveTick = dramaticFreeMove.tick
  dramaticFreeMove.tick = function(state)
    local p = state and state.player
    local armed = false
    if freeMoveApproachesWater(state) and suicuneSurfUnlocked() and p then
      p.surfing = true
      p.surfingPikachu = false
      ground.amphibiousWater = true
      armed = true
    end

    local ok, a, b, c = pcall(previousFreeMoveTick, state)
    if not ok then
      -- Do not leave native Surf armed if the provider's free-move tick fails.
      if armed and p and not currentCellWater(state, p) then
        p.surfing = false
        ground.amphibiousWater = false
      end
      error(a, 0)
    end
    return a, b, c
  end
  dramaticFreeMove.dramaticSuicuneWaterHook = true
end

-- -------------------------------------------------------------------------
-- Suicune battle visual continuity.
-- -------------------------------------------------------------------------
local suicuneBattleVisual = nil

local previousBattleStopGroundRide = stopGroundRide
stopGroundRide = function(game, reason, keepFollowers)
  if reason == "battle" and suicuneRideActive()
     and ground.amphibiousWater == true and ground.sprite then
    suicuneBattleVisual = {
      sprite = ground.sprite,
      mon = ground.mon,
    }
  end
  return previousBattleStopGroundRide(game, reason, keepFollowers)
end

-- Make the visible-Surf subsystem treat our preserved pose exactly like the
-- existing Gen2 battle-remount state, even during the tiny frame where the
-- older remount code has already consumed its own pending snapshot.
local gen2 = mod.exports and mod.exports.gen2Mounts
if gen2 then
  local previousBattlePending = gen2.battleWaterResumePending
  gen2.battleWaterResumePending = function()
    if suicuneBattleVisual then
      local ow = Game.overworld
      if currentCellWater(ow, ow and ow.player) then return true end
      -- A stale visual must never suppress an unrelated future Surf session.
      suicuneBattleVisual = nil
    end
    if type(previousBattlePending) == "function" then
      local ok, pending = pcall(previousBattlePending)
      if ok then return pending == true end
    end
    return false
  end
end

local previousSuicuneBattlePose = Player.pose
function Player:pose()
  local sprite, px, py, facing, phase, flip, hopping = previousSuicuneBattlePose(self)
  local ow = Game.overworld
  if suicuneBattleVisual and suicuneBattleVisual.sprite
     and ow and ow.player == self and currentCellWater(ow, self) then
    local walkPhase = math.floor((tonumber(self.animClock) or 0) / 16) % 2
    return suicuneBattleVisual.sprite, self.px, self.py,
      facing, walkPhase, flip, hopping
  end
  return sprite, px, py, facing, phase, flip, hopping
end

-- Wrap starts last so the current mount follower is hidden immediately (no
-- one-frame duplicate) and a successful Suicune remount retires the preserved
-- battle pose before ordinary rendering resumes.
local previousFollowerPolicyStartFlight = startFlight
startFlight = function(game, mon)
  local ok = previousFollowerPolicyStartFlight(game, mon)
  if ok then
    suicuneBattleVisual = nil
    if mountedFollowersEnabled() then applyFollowerDrawPolicy(mod.exports._mountWorld(game)) end
  end
  return ok
end

local previousFollowerPolicyStartGroundRide = startGroundRide
startGroundRide = function(game, mon)
  local ok = previousFollowerPolicyStartGroundRide(game, mon)
  if ok then
    if ground and ground.species == "SUICUNE" then suicuneBattleVisual = nil end
    if mountedFollowersEnabled() then applyFollowerDrawPolicy(mod.exports._mountWorld(game)) end
  end
  return ok
end

mod.events:on("battle.ended", function(ev)
  if not suicuneBattleVisual then return end
  local result = ev and ev.result
  local mon = suicuneBattleVisual.mon
  if result == "lose"
     or optionValue("remount_after_battle", true) ~= true
     or not healthy(mon) then
    suicuneBattleVisual = nil
  end
end)

mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id
          and payload.key == "show_followers_while_mounted") then return end
  local ow = Game.overworld
  if payload.value == true and ow and mountedNow() then
    -- Previous hidden-policy builds may have removed trailers. One sync is
    -- enough to rebuild them; from here on we leave the pack intact.
    pcall(syncFollowerMods, ow)
    applyFollowerDrawPolicy(ow)
  elseif payload.value ~= true then
    restoreFollowerDraws()
  end
end)

mod.exports.mountedFollowerTrailPreserved = function()
  return mountedFollowersEnabled()
end
mod.exports.suicuneBattleVisualPending = function()
  return suicuneBattleVisual ~= nil
end

log("Mounted follower trail preservation and Suicune free-camera/battle continuity loaded")
end)();
