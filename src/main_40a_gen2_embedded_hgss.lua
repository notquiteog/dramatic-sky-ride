;(function()
-- Gen2 embedded HGSS/PokeMMO source bridge.
--
-- Gen2-3D-Sprites embeds Wilds behind STADIUM2_OVERWORLD_MODELS instead of
-- exposing overworld_wild_spawns as a standalone mod. Reuse DSR's existing
-- native PokeMMO resolver synchronously by presenting that embedded export only
-- for the duration of resolve(). No Player/Overworld/prepare hooks live here.

local PROVIDER_ID = "STADIUM2_OVERWORLD_MODELS"
local WILDS_ID = "overworld_wild_spawns"
local PaletteFX = require("src.render.PaletteFX")
local state = { resolves = 0, lastSpecies = nil, lastStyle = nil, lastError = nil }

local function isGold()
  local generation = mod.exports and mod.exports.runtimeGeneration or nil
  if generation and type(generation.isGen2) == "function" then
    local ok, value = pcall(generation.isGen2, Game)
    return ok and value == true
  end
  return false
end

local function requested2D()
  local rendering = mod.exports and mod.exports.flightRendering or nil
  if rendering and type(rendering.requested) == "function" then
    local ok, value = pcall(rendering.requested)
    if ok and value ~= nil then return tostring(value):lower() ~= "stadium" end
  end
  return true
end

local function findHandle(id)
  if type(mod.find) ~= "function" then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

local function embeddedContext()
  if not isGold() or not requested2D() or findHandle(WILDS_ID) then return nil end
  local provider = findHandle(PROVIDER_ID)
  local ex = provider and provider.exports or nil
  local wilds = ex and ex.wilds or nil
  local render = wilds and wilds.render or nil
  local wildsMod = render and render.mod or nil
  local options = wildsMod and wildsMod.options or nil
  if not (wilds and options and type(options.get) == "function") then return nil end
  local okStyle, style = pcall(options.get, options, "sprite_style")
  if not okStyle then return nil end
  state.lastStyle = style
  if tostring(style or ""):lower() ~= "pokemmo" then return nil end
  return { provider = provider, wilds = wilds }
end

local function resolveRaw(species)
  local ctx = embeddedContext()
  local api = mod.exports and mod.exports.nativePokeMMOMounts or nil
  if not (ctx and api and type(api.resolve) == "function" and type(mod.find) == "function") then
    return nil
  end

  local originalFind = mod.find
  local alias = {
    id = WILDS_ID,
    name = WILDS_ID,
    exports = ctx.wilds,
    dramaticSkyRideEmbeddedAlias = true,
    sourceHandle = ctx.provider,
  }

  mod.find = function(self, id, ...)
    if self == mod and id == WILDS_ID then
      local okReal, real = pcall(originalFind, self, id, ...)
      if okReal and real ~= nil then return real end
      return alias
    end
    return originalFind(self, id, ...)
  end

  local ok, renderer = pcall(api.resolve, species)
  mod.find = originalFind
  if not ok then
    state.lastError = tostring(renderer)
    return nil
  end
  if renderer then
    state.resolves = state.resolves + 1
    state.lastSpecies = species
    state.lastError = nil
  end
  return renderer
end

local function rowForFacing(facing)
  if facing == "left" then return 1 end
  if facing == "right" then return 2 end
  if facing == "up" then return 3 end
  return 0
end

local function walkColumn(walkPhase)
  if tonumber(walkPhase) ~= 1 then return 0 end
  local ow = Game and Game.overworld or nil
  local player = ow and ow.player or nil
  local clock = tonumber(player and player.animClock) or 0
  return math.floor(clock / 8) % 4
end

local function decorate(renderer, species)
  if not (renderer and renderer.def and renderer.def.dramaticSkyRideNativePokeMMO) then
    return renderer
  end

  if type(renderer.setObjPalette) ~= "function" then
    function renderer:setObjPalette(colors, group)
      self.objColors = colors
      self.objGroup = group or "gen2"
      return self
    end
  end

  if renderer.dramaticSkyRideGen2EmbeddedCrop then return renderer end
  local correction = mod.exports and mod.exports.nativePokeMMOSizeCorrection or nil
  local crop = correction and type(correction.cropForDef) == "function"
    and correction.cropForDef(renderer.def) or nil
  if not crop then return renderer end

  renderer.dramaticSkyRideGen2EmbeddedCrop = true
  renderer.dsrGen2EmbeddedQuads = renderer.dsrGen2EmbeddedQuads or {}

  local function quadFor(row, col)
    row = math.max(0, math.min(3, tonumber(row) or 0))
    col = math.max(0, math.min(3, tonumber(col) or 0))
    local key = row * 4 + col
    local quad = renderer.dsrGen2EmbeddedQuads[key]
    if quad then return quad end
    if not (love and love.graphics and love.graphics.newQuad) then return nil end
    quad = love.graphics.newQuad(
      col * crop.tileW + crop.left,
      row * crop.tileH + crop.top,
      crop.width, crop.height, crop.atlasW, crop.atlasH)
    renderer.dsrGen2EmbeddedQuads[key] = quad
    return quad
  end

  renderer.draw = function(self, px, py, camX, camY, facing, walkPhase)
    if not (love and love.graphics and love.graphics.draw) then return end
    local quad = quadFor(rowForFacing(facing), walkColumn(walkPhase))
    if not quad then return end

    local mountScale = 1
    local liveCorrection = mod.exports and mod.exports.nativePokeMMOSizeCorrection or nil
    if liveCorrection and type(liveCorrection.scale) == "function" then
      local okScale, value = pcall(liveCorrection.scale, species)
      value = okScale and tonumber(value) or nil
      if value and value > 0 then mountScale = value end
    end
    local scale = (tonumber(crop.fit) or 1) * mountScale
    local drawnW, drawnH = crop.width * scale, crop.height * scale
    local x = math.floor((px or 0) - (camX or 0))
    local y = math.floor((py or 0) - (camY or 0)) - 4
    local anchorX, anchorY = x + 8, y + 16

    if PaletteFX and PaletteFX.markTrueColor then
      PaletteFX.markTrueColor(
        math.floor(anchorX - drawnW / 2), math.floor(anchorY - drawnH),
        math.ceil(drawnW), math.ceil(drawnH))
    end
    love.graphics.draw(self.image, quad, anchorX, anchorY,
      0, scale, scale, crop.width / 2, crop.height)
  end
  return renderer
end

-- Keep Flight and Ground on the same embedded HGSS resolver. Their normal
-- builders remain the exact fallback when HGSS is unavailable or not selected.
local previousFlightBuilder = buildMountSprite
if type(previousFlightBuilder) == "function" then
  buildMountSprite = function(species, ...)
    local native = decorate(resolveRaw(species), species)
    return native or previousFlightBuilder(species, ...)
  end
end

local previousGroundBuilder = buildGroundMountSprite
if type(previousGroundBuilder) == "function" then
  buildGroundMountSprite = function(species, ...)
    local native = decorate(resolveRaw(species), species)
    return native or previousGroundBuilder(species, ...)
  end
end

local function refreshActive2D()
  if not requested2D() then return end
  if flight and flight.active and flight.species and type(buildMountSprite) == "function" then
    local ok, sprite = pcall(buildMountSprite, flight.species)
    if ok and sprite then flight.sprite = sprite end
  end
  if ground and ground.active and ground.species and type(buildGroundMountSprite) == "function" then
    local ok, sprite = pcall(buildGroundMountSprite, ground.species)
    if ok and sprite then ground.sprite = sprite end
  end
end

mod.events:on("mod.options_changed", function(payload)
  if not payload then return end
  if payload.mod == PROVIDER_ID and payload.key == "sprite_style" then
    refreshActive2D()
  elseif payload.mod == mod.id and payload.key == "flight_mount_renderer" then
    refreshActive2D()
  end
end)

mod.exports.gen2EmbeddedPokeMMOMounts = {
  api = 2,
  providerId = PROVIDER_ID,
  active = function() return embeddedContext() ~= nil end,
  resolve = function(species) return decorate(resolveRaw(species), species) end,
  status = function()
    return {
      active = embeddedContext() ~= nil,
      resolves = state.resolves,
      lastSpecies = state.lastSpecies,
      style = state.lastStyle,
      lastError = state.lastError,
    }
  end,
}

log("Gen2 embedded HGSS/PokeMMO resolver loaded")
end)();
