;(function()
-- alpha.16.4: vanilla progression discovery gates.
--
-- DSR may cross route/city seams while airborne, which can otherwise let a
-- player enter vanilla areas they have never reached through normal gameplay.
-- Track maps reached while NOT flying and gate only the canonical Gen 1
-- overworld progression maps. Unknown/custom map ids stay open by default so
-- map packs and total conversions are not accidentally locked out.

local function appendOptionOnce(row)
  for _, existing in ipairs(OPTION_SCHEMA or {}) do
    if existing.key == row.key then return end
  end
  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = row
end

appendOptionOnce({
  key = "discovery_gates",
  type = "toggle",
  label = "DISCOVERY GATES",
  default = true,
  help = "Block airborne entry into vanilla routes/cities until reached normally. Custom maps stay open by default.",
})
if mod.options and mod.options.define then mod.options:define(OPTION_SCHEMA) end

local function discoveryGatesEnabled()
  return optionValue("discovery_gates", true) == true
end

-- Only stable canonical overworld ids are gated. Unknown ids are assumed to
-- belong to custom content and are deliberately allowed unless another mod
-- explicitly opts them in through registerDiscoveryGate().
local VANILLA_DISCOVERY_GATED = {
  PALLET_TOWN = true,
  VIRIDIAN_CITY = true,
  PEWTER_CITY = true,
  CERULEAN_CITY = true,
  VERMILION_CITY = true,
  LAVENDER_TOWN = true,
  CELADON_CITY = true,
  FUCHSIA_CITY = true,
  SAFFRON_CITY = true,
  CINNABAR_ISLAND = true,
  INDIGO_PLATEAU = true,
  VIRIDIAN_FOREST = true,
}
for i = 1, 25 do VANILLA_DISCOVERY_GATED["ROUTE_" .. i] = true end

-- Optional runtime overrides for compatibility mods. true = gate this map;
-- false = explicitly exempt it. No custom mod has to register anything: an
-- unknown map is allowed by default.
local discoveryOverrides = {}
local reachedCache = nil

local function reachedMaps()
  if type(reachedCache) == "table" then return reachedCache end
  local ok, saved = pcall(mod.save.get, mod.save,
    "legitimately_reached_maps", {})
  reachedCache = ok and type(saved) == "table" and saved or {}
  return reachedCache
end

local function persistReached()
  if not mod.save or not mod.save.set then return end
  pcall(mod.save.set, mod.save, "legitimately_reached_maps", reachedMaps())
end

local function markReached(mapId)
  if type(mapId) ~= "string" or mapId == "" then return false end
  local reached = reachedMaps()
  if reached[mapId] then return false end
  reached[mapId] = true
  persistReached()
  log("progression discovery recorded: %s", mapId)
  return true
end

local function discoveryGatedMap(mapId)
  if type(mapId) ~= "string" or mapId == "" then return false end
  if discoveryOverrides[mapId] ~= nil then return discoveryOverrides[mapId] end
  return VANILLA_DISCOVERY_GATED[mapId] == true
end

local function mapReached(mapId)
  -- Compatibility rule: maps DSR does not recognise as canonical vanilla
  -- progression maps are never blocked merely because they are new/custom.
  if not discoveryGatedMap(mapId) then return true end
  return reachedMaps()[mapId] == true
end

local function currentMapId(game)
  local ow = mod.exports._mountWorld(game)
  return ow and ow.map and ow.map.id or nil
end

local function recordCurrentMapIfLegit(game)
  if flight.active then return end
  local mapId = currentMapId(game)
  if mapId then markReached(mapId) end
end

-- map.entered exposes whether the transition was a warp/connection/boot/etc.
-- The important distinction for DSR is simpler: if its flight state is active,
-- the entry was enabled by airborne traversal and must not unlock that map.
-- Walking, biking/Ground Ride, Surf, scripted warps and ordinary native field
-- moves all count as legitimate reachability.
mod.events:on("map.entered", function(ev)
  if flight.active then return end
  if ev and ev.mapId then markReached(ev.mapId) end
end)

-- Reload the per-save cache when slots change, then seed the currently loaded
-- map. This also makes an existing save usable after installing alpha.16.4:
-- its current location is immediately considered legitimately reached.
mod.events:on("save.loaded", function()
  reachedCache = nil
end)
mod.events:on("save.created", function()
  reachedCache = nil
end)
mod.events:on("game.ready", function(ev)
  reachedCache = nil
  recordCurrentMapIfLegit((ev and ev.game) or Game)
end)

-- Wrap after main_22's story-gate wrapper. Discovery is an additional rule:
-- known vanilla destinations require a prior legitimate visit, then the
-- existing badge/event gate still gets the final say.
if not OverworldState.dramaticSkyRideDiscoveryGateWrapped then
  local crossConnectionWithoutDiscoveryGate = OverworldState.crossConnection
  if type(crossConnectionWithoutDiscoveryGate) == "function" then
    OverworldState.crossConnection = function(self, dir, conn, ...)
      local target = conn and (conn.mapId or conn.map)
      if flight.active and Game.overworld == self and discoveryGatesEnabled()
         and discoveryGatedMap(target) and not mapReached(target) then
        if (flight.storyGateNoticeCooldown or 0) <= 0 then
          notifyHud("AREA NOT VISITED")
          feedback("blocked")
          flight.storyGateNoticeCooldown = 1.0
        end
        return false
      end
      return crossConnectionWithoutDiscoveryGate(self, dir, conn, ...)
    end
  end
  OverworldState.dramaticSkyRideDiscoveryGateWrapped = true
end

-- Extend the public flight-rules surface rather than introducing a second API.
-- These helpers are intentionally generic so custom-map mods can opt in/out
-- without depending on DSR internals, while requiring no changes at all for
-- ordinary custom maps.
mod.exports.flightRules = mod.exports.flightRules or {}
mod.exports.flightRules.discoveryGates = discoveryGatesEnabled
mod.exports.flightRules.isMapReached = function(mapId)
  return mapReached(mapId)
end
mod.exports.flightRules.markMapReached = function(mapId)
  return markReached(mapId)
end
mod.exports.flightRules.registerDiscoveryGate = function(mapId, enabled)
  if type(mapId) ~= "string" or mapId == "" then return false end
  discoveryOverrides[mapId] = enabled ~= false
  return true
end
mod.exports.flightRules.clearDiscoveryGateOverride = function(mapId)
  if type(mapId) ~= "string" or mapId == "" then return false end
  discoveryOverrides[mapId] = nil
  return true
end

log("alpha.16.4 vanilla discovery progression gates loaded")
end)();
