(function()
-- Wilds / multi-provider mounted-runtime polish.
--
-- 1) Followers are hidden on every mount by default. Users may opt back in,
--    in which case every follower except the Pokemon currently being ridden
--    remains visible.
-- 2) Reassert the 1ST/3RD body bearing after the full overworld update so a
--    late follower/runtime owner cannot leave Gen 2 Wilds mounts facing a
--    stale compass direction.
-- 3) Preserve Suicune Ground Ride through seamless land/water map connections.

local function appendOptionOnce(row)
  for _, existing in ipairs(OPTION_SCHEMA or {}) do
    if existing.key == row.key then return end
  end
  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = row
end

appendOptionOnce({
  key = "show_followers_while_mounted",
  type = "toggle",
  label = "MOUNT FOLLOWERS",
  default = false,
  help = "Show followers while mounted. The Pokemon being ridden stays hidden.",
})
if mod.options and mod.options.define then mod.options:define(OPTION_SCHEMA) end

local function followersWhileMountedEnabled()
  return optionValue("show_followers_while_mounted", false) == true
end

local function callBoolExport(name)
  local fn = mod.exports and mod.exports[name]
  if type(fn) ~= "function" then return false end
  local ok, value = pcall(fn)
  return ok and value == true
end

local function callValueExport(name)
  local fn = mod.exports and mod.exports[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn)
  return ok and value or nil
end

local function mountedStateActive()
  local ow = Game.overworld
  local surfing = ow and ow.player and ow.player.surfing == true
  return flight.active == true
      or (ground and ground.active == true)
      or callBoolExport("isWaterRiding")
      or surfing
end

local function canonicalSpecies(value)
  if value == nil then return nil end
  return tostring(value):upper():gsub("[^A-Z0-9]", "")
end

local function currentMountIdentity()
  if flight.active then return flight.species, flight.mon end
  if ground and ground.active then return ground.species, ground.mon end
  if callBoolExport("isWaterRiding") then
    return callValueExport("waterMountSpecies"), nil
  end
  return nil, nil
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

local function mountedFollowerEntity(entity, player)
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

local function entityIsCurrentMountFollower(entity, mountSpecies, mountMon)
  if mountMon and type(entity) == "table" and entity.pokepcMon == mountMon then
    return true
  end
  local follower = canonicalSpecies(followerSpecies(entity))
  local mounted = canonicalSpecies(mountSpecies)
  return follower ~= nil and mounted ~= nil and follower == mounted
end

-- Rebind the shared purge function. Existing flight/ground suspend and update
-- paths all reference this same local cell, so the policy applies everywhere
-- without creating a second follower runtime owner.
purgeFollowersDuringFlight = function(ow, captured)
  if not ow or not mountedStateActive() then return captured end

  captured = captured or {}
  captured.entities = captured.entities or {}
  captured.npcs = captured.npcs or {}

  local showOthers = followersWhileMountedEnabled()
  local mountSpecies, mountMon = currentMountIdentity()

  local function purgeList(list, bucket)
    for i = #(list or {}), 1, -1 do
      local entity = list[i]
      if mountedFollowerEntity(entity, ow.player) then
        local remove = not showOthers
          or entityIsCurrentMountFollower(entity, mountSpecies, mountMon)
        if remove then
          if bucket and not contains(bucket, entity) then bucket[#bucket + 1] = entity end
          table.remove(list, i)
        end
      end
    end
  end

  purgeList(ow.entities, captured.entities)
  purgeList(ow.npcs, captured.npcs)
  return captured
end

-- Suicune uses native p.surfing only as a collision/progression state. The
-- alpha.14 map wrapper predates amphibious mounts and interprets any surfing
-- player as incompatible with Ground Ride. Mask that flag only while a
-- seamless map connection is being re-rooted, then restore the correct state
-- from the destination cell before the frame returns to rendering.
local setMap = OverworldState.setMap
function OverworldState:setMap(mapId, x, y, facing, opts, ...)
  local p = self.player
  local seamless = type(opts) == "table" and opts.seamless == true
  local preserveSuicune = seamless and p and ground and ground.active
    and ground.species == "SUICUNE" and ground.amphibiousWater == true

  if not preserveSuicune then
    return setMap(self, mapId, x, y, facing, opts, ...)
  end

  local extra = { ... }
  p.surfing = false
  local result = { pcall(function()
    return setMap(self, mapId, x, y, facing, opts, unpackArgs(extra))
  end) }
  local ok = table.remove(result, 1)

  local live = self.player
  if live then
    local waterHere = false
    if self.map and self.map.inBounds and self.map.isWaterCell
       and self.map:inBounds(live.cellX, live.cellY) then
      waterHere = self.map:isWaterCell(live.cellX, live.cellY) == true
    end
    live.surfing = waterHere
    live.surfingPikachu = false
    ground.amphibiousWater = waterHere

    -- setMap saw the temporary land state. Correct only the water destination
    -- music selection; land destinations already received the right map song.
    if waterHere then
      local okMusic, Music = pcall(require, "src.core.Music")
      if okMusic and Music and Music.playMap and self.map then
        pcall(Music.playMap, Game.data, self.map.id, false, true)
      end
    end
  end

  if not ok then error(result[1], 0) end
  return unpackArgs(result)
end

local function stabilizeFlightFacing()
  if not (flight.active and isFreeCamera()) then return end
  local ow = Game.overworld
  local p = ow and ow.player
  if not p then return end

  dramaticFirstPerson = dramaticFirstPerson or dramaticModule("FirstPerson")
  local fp = dramaticFirstPerson
  if not fp then return end

  local wx, wz = 0, 0
  if flight.phase == "cruise" and type(fp.moveVector) == "function"
     and type(fp.moveWorld) == "function" then
    local okMove, mx, mz = pcall(fp.moveVector)
    if okMove then
      local okWorld, x, z = pcall(fp.moveWorld, mx or 0, mz or 0)
      if okWorld then wx, wz = x or 0, z or 0 end
    end
  end

  if type(fp.pointBody) == "function" then
    local okFacing, value = pcall(fp.pointBody, wx, wz)
    if okFacing and value then p.facing = value end
  elseif fp.yaw ~= nil then
    p.facing = facingFromYaw(tonumber(fp.yaw) or 0)
  end
end

local followersWereSuppressed = false
local update = OverworldState.update
function OverworldState:update(dt, ...)
  local result = update(self, dt, ...)
  if Game.overworld ~= self then return result end

  if mountedStateActive() then
    -- This final pass also covers Visible Surf, whose private water state does
    -- not use the flight/ground suspend helpers.
    purgeFollowersDuringFlight(self)
    followersWereSuppressed = true
    stabilizeFlightFacing()
  elseif followersWereSuppressed then
    followersWereSuppressed = false
    -- Water mounts have no captured follower table of their own. Ask the one
    -- authoritative runtime to rebuild once when every mount has ended.
    pcall(syncFollowerMods, self)
  end
  return result
end

mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id
          and payload.key == "show_followers_while_mounted") then return end
  local ow = Game.overworld
  if not (ow and mountedStateActive()) then return end
  if payload.value == true then pcall(syncFollowerMods, ow) end
  purgeFollowersDuringFlight(ow)
end)

mod.exports.mountedFollowerPolicy = {
  showFollowers = followersWhileMountedEnabled,
  mounted = mountedStateActive,
}

log("Mounted follower policy, Wilds camera-facing guard and Suicune seam polish loaded")
end)();
