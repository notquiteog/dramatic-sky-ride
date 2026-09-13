;(function()
-- -------------------------------------------------------------------------
-- Minimal Gen2 voxel calibration.
--
-- No renderer switching, no battle hooks and no follower surgery live here.
-- This file only:
--   1) prevents DSR's experimental native Stadium2 renderer from running when
--      Randy is the selected Gen2 provider;
--   2) supplies canonical mount heights when Gold data omits them;
--   3) prevents bike/surf player sheets from becoming the mounted rider crop.
-- -------------------------------------------------------------------------

local generation = mod.exports.runtimeGeneration or {}
local function isGold()
  return type(generation.isGen2) == "function"
    and generation.isGen2(Game) == true
end

-- main_41's local rendererSelected() calls flightRendering.usesStadium().
-- External Gen2 consumers use usesGen2VoxelStadium(), so making only the
-- generic legacy seam return false is enough to guarantee one Stadium owner.
local rendering = mod.exports and mod.exports.flightRendering or nil
if type(rendering) == "table" and type(rendering.usesStadium) == "function"
   and not rendering._dramaticSkyRideGen2NativeGuard then
  local rawUsesStadium = rendering.usesStadium
  rendering.usesStadium = function()
    if isGold() and type(rendering.usesGen2VoxelStadium) == "function" then
      local ok, external = pcall(rendering.usesGen2VoxelStadium)
      if ok and external == true then return false end
    end
    local ok, value = pcall(rawUsesStadium)
    return ok and value == true
  end
  rendering._dramaticSkyRideGen2NativeGuard = true
end

local MOUNT_HEIGHT_METERS = {
  CHARIZARD = 1.7, PIDGEOT = 1.5, FEAROW = 1.2, GOLBAT = 1.6,
  AERODACTYL = 1.8, ARTICUNO = 1.7, ZAPDOS = 1.6, MOLTRES = 2.0,
  DRAGONAIR = 4.0, DRAGONITE = 2.2,
  ARCANINE = 1.9, RAPIDASH = 1.7, DODRIO = 1.8, RHYHORN = 1.0,
  RHYDON = 1.9, KANGASKHAN = 2.2, TAUROS = 1.4, SNORLAX = 2.1,
  BLASTOISE = 1.6, TENTACRUEL = 1.6, GYARADOS = 6.5, LAPRAS = 2.5,
  NOCTOWL = 1.6, CROBAT = 1.8, XATU = 1.5, SKARMORY = 1.7,
  LUGIA = 5.2, HO_OH = 3.8,
  MEGANIUM = 1.8, GIRAFARIG = 1.5, URSARING = 1.8, DONPHAN = 1.1,
  STANTLER = 1.4, RAIKOU = 1.9, ENTEI = 2.1, SUICUNE = 2.0,
  TYRANITAR = 2.0, FERALIGATR = 2.3, MANTINE = 2.1, KINGDRA = 1.8,
}

local function cleanSpecies(value)
  if value == nil then return nil end
  return tostring(value):upper():gsub("[^A-Z0-9]", "")
end

local function canonicalHeight(species)
  return MOUNT_HEIGHT_METERS[cleanSpecies(species)]
end

local rawHeight = mod.exports.mountPokedexHeightMeters
local rawScale = mod.exports.mountVisualScale
if type(rawHeight) == "function" and type(rawScale) == "function"
   and not mod.exports._gen2VoxelCanonicalSizeCalibration then
  mod.exports.mountPokedexHeightMeters = function(species)
    local ok, value = pcall(rawHeight, species)
    value = ok and tonumber(value) or nil
    if value and value > 0 then return value end
    return canonicalHeight(species)
  end

  mod.exports.mountVisualScale = function(species)
    local okHeight, nativeHeight = pcall(rawHeight, species)
    nativeHeight = okHeight and tonumber(nativeHeight) or nil
    if nativeHeight and nativeHeight > 0 then
      local okScale, value = pcall(rawScale, species)
      value = okScale and tonumber(value) or nil
      if value and value > 0 then return value end
    end

    local meters = canonicalHeight(species)
    if not meters then
      local okScale, value = pcall(rawScale, species)
      return okScale and tonumber(value) or 1
    end
    local percent = tonumber(optionValue("mount_size_" .. tostring(species):lower(), 100)) or 100
    percent = clamp(percent, 50, 200)
    if optionValue("pokedex_mount_sizes", true) ~= true then return percent / 100 end
    return clamp(meters / 1.70, 0.50, 4.00) * percent / 100
  end
  mod.exports._gen2VoxelCanonicalSizeCalibration = true
end

local rawRiderSource = mod.exports._riderSourceSprite
local function vehicleSheet(sprite)
  local id = sprite and sprite.def and tostring(sprite.def.id or ""):upper() or ""
  return id:find("BIKE", 1, true) ~= nil
      or id:find("SURF", 1, true) ~= nil
      or id:find("SKATE", 1, true) ~= nil
end

local function normalGoldSprite(player)
  local ow = mod.exports._mountWorld and mod.exports._mountWorld(Game) or nil
  local def = ow and ow.sprites and ow.sprites.SPRITE_CHRIS or nil
  if not def then return nil end
  local sprite = SpriteRenderer.new(def, "dsr_gen2_clean_rider_source")
  if type(ow.applySpritePalette) == "function" then
    local holder = { spriteDef = def, sprite = sprite }
    pcall(ow.applySpritePalette, ow, holder)
  elseif player and player.sprite and player.sprite.objColors
     and type(sprite.setObjPalette) == "function" then
    sprite:setObjPalette(player.sprite.objColors, player.sprite.objGroup)
  end
  return sprite
end

if type(rawRiderSource) == "function" and not mod.exports._gen2VoxelCleanRiderSource then
  mod.exports._riderSourceSprite = function(player)
    local sprite = rawRiderSource(player)
    if isGold() and vehicleSheet(sprite) then
      return normalGoldSprite(player) or sprite
    end
    return sprite
  end
  mod.exports._gen2VoxelCleanRiderSource = true
end

mod.exports.gen2VoxelCalibration = {
  api = 1,
  canonicalHeight = canonicalHeight,
  nativeRendererBlocked = function()
    if not (isGold() and rendering and type(rendering.usesGen2VoxelStadium) == "function") then
      return false
    end
    local ok, value = pcall(rendering.usesGen2VoxelStadium)
    return ok and value == true
  end,
}

log("Gen2 voxel calibration loaded (stable external owner, canonical sizes, clean rider source)")
end)();