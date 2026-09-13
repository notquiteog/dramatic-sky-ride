;(function()
-- -------------------------------------------------------------------------
-- Public airborne 2D sprite-source registry.
--
-- Match the small author-facing contract used by Shane's Free Fly/Wild Skies:
-- registerSpriteSource({ id|mod, resolve(exports, game, species, dex) }) and
-- unregisterSpriteSource(id). This registry only dresses DSR's 2D flying mount;
-- Stadium models remain a separate renderer selected through FLIGHT RENDERER.
-- -------------------------------------------------------------------------

local spriteSources = {}

local function sourceId(source)
  return type(source) == "table" and (source.id or source.mod) or nil
end

local function removeSource(id)
  for i = #spriteSources, 1, -1 do
    local source = spriteSources[i]
    if sourceId(source) == id then
      table.remove(spriteSources, i)
      return true
    end
  end
  return false
end

local function refreshActiveFlightSprite()
  if not (flight.active and flight.species) then return end
  local sprite = buildMountSprite(flight.species)
  if sprite then flight.sprite = sprite end
end

local function registerSource(source)
  if type(source) ~= "table" or type(source.resolve) ~= "function" then
    return false, "source table with a resolve function required"
  end
  local id = sourceId(source)
  if id == nil then return false, "source needs an id or a mod" end

  removeSource(id)
  -- Registered sources outrank DSR's built-in Wilds/PokePC provider adapters.
  -- Re-registering replaces and promotes the source, mirroring skylib.
  table.insert(spriteSources, 1, source)
  refreshActiveFlightSprite()
  return true
end

local function unregisterSource(id)
  local removed = removeSource(id)
  if removed then refreshActiveFlightSprite() end
  return removed
end

local function sourceExports(source)
  if not source.mod then return nil, true end
  if not mod.find then return nil, false end
  local ok, handle = pcall(mod.find, mod, source.mod)
  if not (ok and handle) then return nil, false end
  return handle.exports, true
end

local function sourcePath(species)
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[species]
  local dex = def and tonumber(def.dex) or nil

  for _, source in ipairs(spriteSources) do
    local exports, enabled = sourceExports(source)
    if enabled then
      local ok, provided = pcall(source.resolve, exports, Game, species, dex)
      if ok and type(provided) == "table" and type(provided.image) == "string"
          and (tonumber(provided.frames) or 1) > 1 then
        -- DSR's mount renderer uses the engine's six-frame walker layout.
        -- Refuse incompatible/static art and fall through to Wilds/PokePC.
        local frames = tonumber(provided.frames) or 0
        if frames >= 6 and provided.walker ~= false then
          local okImage, image = pcall(Assets.image, provided.image)
          if okImage and image then
            local width, height = image:getDimensions()
            if width >= 16 and height >= 96 then
              return provided.image, sourceId(source)
            end
          end
        end
      end
    end
  end
  return nil
end

local providerFollowerPath = followerPath
followerPath = function(species)
  local path, provider = sourcePath(species)
  if path then
    if provider ~= mod.exports._activeFlightSpriteSource then
      mod.exports._activeFlightSpriteSource = provider
      log("Airborne sprite source: %s", tostring(provider))
    end
    return path
  end
  mod.exports._activeFlightSpriteSource = nil
  return providerFollowerPath(species)
end

mod.exports.registerSpriteSource = registerSource
mod.exports.unregisterSpriteSource = unregisterSource
mod.exports.airborneSpriteSources = function()
  local out = {}
  for _, source in ipairs(spriteSources) do
    out[#out + 1] = sourceId(source)
  end
  return out
end

-- A source whose options change can re-dress the live mount immediately.
mod.events:on("mod.options_changed", function(payload)
  local id = payload and payload.mod
  if id == nil then return end
  for _, source in ipairs(spriteSources) do
    if source.id == id or source.mod == id then
      refreshActiveFlightSprite()
      return
    end
  end
end)

log("airborne 2D sprite-source API loaded")
end)()
