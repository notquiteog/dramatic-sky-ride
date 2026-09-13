(function()
-- Final mounted-follower visibility policy from in-game validation.
--
-- The opt-in follower display is intentionally LAND GROUND RIDE only.
-- Flight and every water state (native Surf, visible Surf, and Suicune's
-- amphibious water-running state) always hide followers. We keep Wilds'
-- trailer entities alive and moving, and suppress only their draw calls, so
-- the authoritative follower chain is never rebuilt on top of the player.

local function waterRideActive()
  local ex = mod.exports or {}
  if type(ex.isWaterRiding) == "function" then
    local ok, active = pcall(ex.isWaterRiding)
    if ok and active == true then return true end
  end
  return false
end

local function airOrWaterMounted()
  local ow = Game.overworld
  local p = ow and ow.player
  return flight.active == true
      or waterRideActive()
      or (p and p.surfing == true)
      or (ground and ground.active == true and ground.amphibiousWater == true)
end

local function landGroundRideActive()
  local ow = Game.overworld
  local p = ow and ow.player
  return ground and ground.active == true
      and flight.active ~= true
      and not waterRideActive()
      and not (p and p.surfing == true)
      and ground.amphibiousWater ~= true
end

-- Keep the existing key for save compatibility, but make the UI contract
-- explicit: enabling it affects Ground Ride on land only.
for _, row in ipairs(OPTION_SCHEMA or {}) do
  if row.key == "show_followers_while_mounted" then
    row.label = "GROUND FOLLOWERS"
    row.help = "Show followers during Ground Ride on land only. Hidden in flight and on water; the ridden Pokemon stays hidden."
    break
  end
end
if mod.options and mod.options.define then mod.options:define(OPTION_SCHEMA) end

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

-- This layer only owns the extra air/water hiding. main_35 continues to own
-- the active-mount-only hide while followers are enabled on land Ground Ride.
local hiddenForAirWater = setmetatable({}, { __mode = "k" })

local function hideEntity(entity)
  if not entity or hiddenForAirWater[entity] then return end
  if type(entity.draw) ~= "function" then return end
  hiddenForAirWater[entity] = entity.draw
  entity.draw = function() end
end

local function restoreAirWaterDraws()
  for entity, draw in pairs(hiddenForAirWater) do
    if entity then entity.draw = draw end
    hiddenForAirWater[entity] = nil
  end
end

local function hideAllFollowersNonDestructive(ow)
  if not ow then return end
  local seen = setmetatable({}, { __mode = "k" })
  local function visit(list)
    for _, entity in ipairs(list or {}) do
      if not seen[entity] and isFollowerEntity(entity, ow.player) then
        seen[entity] = true
        hideEntity(entity)
      end
    end
  end
  visit(ow.entities)
  visit(ow.npcs)

  -- Do not retain stale overrides after Wilds replaces an entity at a map or
  -- battle boundary.
  for entity, draw in pairs(hiddenForAirWater) do
    if not seen[entity] then
      if entity then entity.draw = draw end
      hiddenForAirWater[entity] = nil
    end
  end
end

local previousPurgeFollowers = purgeFollowersDuringFlight
purgeFollowersDuringFlight = function(ow, captured)
  local result = previousPurgeFollowers(ow, captured)
  if airOrWaterMounted() then
    hideAllFollowersNonDestructive(ow)
  else
    restoreAirWaterDraws()
  end
  return result
end

local previousRestoreFollowers = restoreFollowers
restoreFollowers = function(ow)
  restoreAirWaterDraws()
  return previousRestoreFollowers(ow)
end

-- Reassert after the complete overworld tick because Wilds may recreate or
-- refresh trailers late in the frame. This guarantees no follower is visible
-- during flight/Surf even when the option is enabled.
local update = OverworldState.update
function OverworldState:update(dt, ...)
  local result = update(self, dt, ...)
  if Game.overworld == self then
    if airOrWaterMounted() then
      hideAllFollowersNonDestructive(self)
    else
      restoreAirWaterDraws()
    end
  end
  return result
end

mod.exports.mountedFollowerPolicy = mod.exports.mountedFollowerPolicy or {}
mod.exports.mountedFollowerPolicy.landGroundOnly = function()
  return landGroundRideActive()
end
mod.exports.mountedFollowerPolicy.hiddenInAirOrWater = function()
  return airOrWaterMounted()
end

log("Ground-only follower visibility policy loaded")
end)();
