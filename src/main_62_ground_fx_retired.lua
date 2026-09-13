;(function()
-- -------------------------------------------------------------------------
-- Retire the legacy Flight ground marker/shadow system on every generation.
--
-- The old landing marker and dynamic shadow shared a synthetic overworld
-- sprite entity. That entity is presentation-only, but voxel/3D renderers are
-- allowed to treat any overworld entity as a real sprite card. In practice it
-- can therefore become a giant duplicate trainer/Pokemon at ground level.
--
-- This layer deliberately removes the feature instead of adding another
-- renderer-specific exception:
--   * no ground-FX entity is created in Gen 1 or Gen 2;
--   * any stale/hot-reloaded legacy entity is purged from entities and NPCs;
--   * LANDING MARKER and DYNAMIC SHADOW are removed from DSR's option schema.
-- -------------------------------------------------------------------------

local RETIRED_OPTIONS = {
  landing_marker = true,
  dynamic_shadow = true,
}

local function legacyGroundFx(entity)
  if type(entity) ~= "table" then return false end
  if entity == flight.groundFxEntity or entity.skyRideGroundFx == true then
    return true
  end
  if tostring(entity.id or ""):lower() == "sky_ride_ground_fx" then
    return true
  end
  local sprite = entity.sprite
  local def = sprite and sprite.def
  return def and tostring(def.id or ""):upper() == "SKY_RIDE_GROUND_FX"
end

local function purgeList(list)
  local removed = 0
  if type(list) ~= "table" then return removed end
  for i = #list, 1, -1 do
    if legacyGroundFx(list[i]) then
      table.remove(list, i)
      removed = removed + 1
    end
  end
  return removed
end

local retiredState = {
  purged = 0,
}

local function purgeGroundFx(ow)
  if ow then
    retiredState.purged = retiredState.purged + purgeList(ow.entities)
    retiredState.purged = retiredState.purged + purgeList(ow.npcs)
  end
  flight.groundFxEntity = nil
  flight.groundFxSprite = nil
  return nil
end

-- Hard-disable every construction/refresh seam used by the original feature.
-- These are locals in the concatenated DSR chunk, so replacing them here also
-- covers old Gen1 calls and the newer Gen2 bridge without touching gameplay.
landingMarkerEnabled = function() return false end
dynamicShadowEnabled = function() return false end
buildGroundFxSprite = function() return nil end
redrawGroundFx = function(ow) return purgeGroundFx(ow) end
ensureGroundFxEntity = function(ow) return purgeGroundFx(ow) end

-- Remove the two retired controls from the published schema. Existing saved
-- values may remain in a user's settings file, but they are no longer exposed
-- or consulted and cannot recreate the entity.
for i = #(OPTION_SCHEMA or {}), 1, -1 do
  local row = OPTION_SCHEMA[i]
  if type(row) == "table" and RETIRED_OPTIONS[row.key] then
    table.remove(OPTION_SCHEMA, i)
  end
end
if mod.options and mod.options.define then
  mod.options:define(OPTION_SCHEMA)
end

-- Purge after every overworld tick as a final compatibility guard. Normally
-- nothing is present because ensureGroundFxEntity is now a no-op; this catches
-- stale objects left behind by a hot reload or another old compatibility layer.
local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousUpdate(self, dt, ...)
  if Game and mod.exports and type(mod.exports._mountWorld) == "function" then
    local ow = mod.exports._mountWorld(Game)
    if ow == self then purgeGroundFx(self) end
  end
  return result
end

local function purgeLiveWorld()
  if not (Game and mod.exports and type(mod.exports._mountWorld) == "function") then
    return
  end
  purgeGroundFx(mod.exports._mountWorld(Game))
end

mod.events:on("game.ready", purgeLiveWorld)
mod.events:on("mods.loaded", purgeLiveWorld)
mod.events:on("mod.options_changed", purgeLiveWorld)

mod.exports.groundFxRetired = {
  api = 1,
  retired = function() return true end,
  purged = function() return retiredState.purged end,
}

purgeLiveWorld()
log("legacy Flight ground marker/dynamic shadow retired globally (Gen1 + Gen2)")
end)();
