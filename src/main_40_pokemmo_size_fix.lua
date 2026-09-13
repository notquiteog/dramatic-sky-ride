(function()
-- -------------------------------------------------------------------------
-- Native PokeMMO apparent-size correction.
--
-- main_38 deliberately reads the original high-resolution Wilds atlas instead
-- of the generated 16x96 walker sheet. Those source tiles contain transparent
-- margins, though, so scaling the entire 32/64px tile makes the visible Pokemon
-- smaller than the same species rendered through Wilds' trimmed runtime sheet.
--
-- This late layer mirrors Wilds' shared opaque-bounds idea without throwing
-- away source detail: one stable union crop is measured across the 4x4 atlas,
-- then that crop is fitted to the same conceptual 16x16 mount card before the
-- normal DSR Pokédex/user scale is applied. It also supplies canonical Johto
-- heights when the active Gen2 content provider does not expose dexEntry height.
-- -------------------------------------------------------------------------
local POKEDEX_REFERENCE_METERS = 1.70
local ALPHA_EPSILON = 0.001
local nativeCropCache = {}
local correctedVoxelMeshes = {}

local GEN2_HEIGHT_METERS = {
  FERALIGATR = 2.3,
  MEGANIUM = 1.8,
  NOCTOWL = 1.6,
  CROBAT = 1.8,
  XATU = 1.5,
  URSARING = 1.8,
  GIRAFARIG = 1.5,
  MANTINE = 2.1,
  SKARMORY = 1.7,
  KINGDRA = 1.8,
  DONPHAN = 1.1,
  STANTLER = 1.4,
  RAIKOU = 1.9,
  ENTEI = 2.1,
  SUICUNE = 2.0,
  TYRANITAR = 2.0,
  LUGIA = 5.2,
  HO_OH = 3.8,
}

local previousMountVisualScale = mod.exports and mod.exports.mountVisualScale or nil
local previousPokedexHeight = mod.exports and mod.exports.mountPokedexHeightMeters or nil

local function canonicalFallbackHeight(species)
  return GEN2_HEIGHT_METERS[tostring(species or ""):upper()]
end

local function actualPokedexHeight(species)
  if type(previousPokedexHeight) == "function" then
    local ok, value = pcall(previousPokedexHeight, species)
    value = ok and tonumber(value) or nil
    if value and value > 0 then return value end
  end
  return canonicalFallbackHeight(species)
end

local function correctedMountScale(species)
  local base = 1
  if type(previousMountVisualScale) == "function" then
    local ok, value = pcall(previousMountVisualScale, species)
    value = ok and tonumber(value) or nil
    if value and value > 0 then base = value end
  end

  -- If the content provider already supplied a valid height, main_21's result
  -- is authoritative and we do not alter it.
  if type(previousPokedexHeight) == "function" then
    local ok, providerHeight = pcall(previousPokedexHeight, species)
    providerHeight = ok and tonumber(providerHeight) or nil
    if providerHeight and providerHeight > 0 then return base end
  end

  local meters = canonicalFallbackHeight(species)
  if not meters or optionValue("pokedex_mount_sizes", true) ~= true then
    return base
  end

  local percent = tonumber(optionValue(
    "mount_size_" .. tostring(species):lower(), 100)) or 100
  percent = clamp(percent, 50, 200)
  return clamp(meters / POKEDEX_REFERENCE_METERS, 0.50, 4.00)
    * percent / 100
end

-- Publish the corrected value. main_38 resolves this export dynamically every
-- time it draws/builds a native card, so no direct dependency between chunks
-- is required. Other late compatibility layers also get the same Gen2 fallback.
mod.exports.mountVisualScale = correctedMountScale
mod.exports.mountPokedexHeightMeters = actualPokedexHeight

local function nativeDef(def)
  return def and def.dramaticSkyRideNativePokeMMO == true
end

local function cropKey(def)
  return table.concat({ tostring(def and def.image),
    tostring(def and def.dramaticSkyRideNativeTileW),
    tostring(def and def.dramaticSkyRideNativeTileH) }, "#")
end

local function fullTileCrop(def, image)
  local iw, ih = image:getDimensions()
  local tileW = tonumber(def.dramaticSkyRideNativeTileW) or (iw / 4)
  local tileH = tonumber(def.dramaticSkyRideNativeTileH) or (ih / 4)
  return {
    left = 0, top = 0, right = tileW, bottom = tileH,
    width = tileW, height = tileH,
    fit = math.min(16 / math.max(1, tileW), 16 / math.max(1, tileH), 1),
    tileW = tileW, tileH = tileH, atlasW = iw, atlasH = ih,
    trimmed = false,
  }
end

local function measureNativeCrop(def, image)
  if not nativeDef(def) or not image then return nil end
  local key = cropKey(def)
  if nativeCropCache[key] then return nativeCropCache[key] end

  local fallback = fullTileCrop(def, image)
  if not (Assets and type(Assets.imageData) == "function") then
    nativeCropCache[key] = fallback
    return fallback
  end

  local okData, data = pcall(Assets.imageData, def.image)
  if not (okData and data and data.getDimensions and data.getPixel) then
    nativeCropCache[key] = fallback
    return fallback
  end

  local iw, ih = data:getDimensions()
  local tileW = math.floor(tonumber(def.dramaticSkyRideNativeTileW) or (iw / 4))
  local tileH = math.floor(tonumber(def.dramaticSkyRideNativeTileH) or (ih / 4))
  if tileW <= 0 or tileH <= 0 then
    nativeCropCache[key] = fallback
    return fallback
  end

  local left, top = tileW, tileH
  local right, bottom = 0, 0
  local found = false

  -- One union bound across every direction/frame gives all animations the same
  -- pivot and prevents the mount from wobbling as individual frame silhouettes
  -- change. Coordinates are measured inside a tile, not across the whole atlas.
  for row = 0, 3 do
    for col = 0, 3 do
      local ox, oy = col * tileW, row * tileH
      for y = 0, tileH - 1 do
        for x = 0, tileW - 1 do
          local _, _, _, a = data:getPixel(ox + x, oy + y)
          if (tonumber(a) or 0) > ALPHA_EPSILON then
            found = true
            if x < left then left = x end
            if y < top then top = y end
            if x + 1 > right then right = x + 1 end
            if y + 1 > bottom then bottom = y + 1 end
          end
        end
      end
    end
  end

  if not found or right <= left or bottom <= top then
    nativeCropCache[key] = fallback
    return fallback
  end

  local contentW = right - left
  local contentH = bottom - top
  local crop = {
    left = left, top = top, right = right, bottom = bottom,
    width = contentW, height = contentH,
    -- Match Wilds' max-fit semantics conceptually: the visible opaque union,
    -- not the transparent source tile, owns the base 16px card size.
    fit = math.min(16 / math.max(1, contentW),
                   16 / math.max(1, contentH), 1),
    tileW = tileW, tileH = tileH, atlasW = iw, atlasH = ih,
    trimmed = true,
  }
  nativeCropCache[key] = crop
  return crop
end

local function rowForFacing(facing)
  if facing == "left" then return 1 end
  if facing == "right" then return 2 end
  if facing == "up" then return 3 end
  return 0
end

local function rowForEngineFrame(frame)
  frame = tonumber(frame) or 0
  if frame == 1 or frame == 4 then return 3 end
  if frame == 2 or frame == 5 then return 1 end
  return 0
end

local function nativeWalkColumn(walkPhase)
  if tonumber(walkPhase) ~= 1 then return 0 end
  local ow = Game and Game.overworld or nil
  local player = ow and ow.player or nil
  local clock = tonumber(player and player.animClock) or 0
  return math.floor(clock / 8) % 4
end

local function croppedQuad(renderer, crop, row, col)
  renderer.dsrCroppedNativeQuads = renderer.dsrCroppedNativeQuads or {}
  local key = row * 4 + col
  if renderer.dsrCroppedNativeQuads[key] then
    return renderer.dsrCroppedNativeQuads[key]
  end
  if not (love and love.graphics and love.graphics.newQuad) then return nil end
  local q = love.graphics.newQuad(
    col * crop.tileW + crop.left,
    row * crop.tileH + crop.top,
    crop.width, crop.height,
    crop.atlasW, crop.atlasH)
  renderer.dsrCroppedNativeQuads[key] = q
  return q
end

local function decorateNativeRenderer(renderer)
  if not (renderer and nativeDef(renderer.def) and renderer.image) then
    return renderer
  end
  if renderer.dramaticSkyRideOpaqueCropFix then return renderer end

  local crop = measureNativeCrop(renderer.def, renderer.image)
  if not crop then return renderer end
  renderer.dramaticSkyRideOpaqueCropFix = true
  renderer.def.dramaticSkyRideNativeCropLeft = crop.left
  renderer.def.dramaticSkyRideNativeCropTop = crop.top
  renderer.def.dramaticSkyRideNativeCropWidth = crop.width
  renderer.def.dramaticSkyRideNativeCropHeight = crop.height
  renderer.def.dramaticSkyRideNativeFit = crop.fit

  renderer.frames = renderer.frames or {}
  renderer.frames[0] = croppedQuad(renderer, crop, 0, 0)
  renderer.frames[1] = croppedQuad(renderer, crop, 3, 0)
  renderer.frames[2] = croppedQuad(renderer, crop, 1, 0)
  renderer.frames[3] = croppedQuad(renderer, crop, 0, 2)
  renderer.frames[4] = croppedQuad(renderer, crop, 3, 2)
  renderer.frames[5] = croppedQuad(renderer, crop, 1, 2)

  renderer.draw = function(self, px, py, camX, camY, facing, walkPhase,
                           _stepFlip, _topHalf)
    if not (love and love.graphics and love.graphics.draw) then return end
    local row = rowForFacing(facing)
    local col = nativeWalkColumn(walkPhase)
    local quad = croppedQuad(self, crop, row, col)
    if not quad then return end

    local species = self.def and self.def.dramaticSkyRideMountSpecies
    local mountScale = correctedMountScale(species)
    local scale = crop.fit * mountScale
    local drawnW = crop.width * scale
    local drawnH = crop.height * scale

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

-- main_38 owns the initial native renderer selection. Decorate its returned
-- renderer after that decision so all non-PokeMMO and fallback paths remain
-- exactly untouched.
local previousPokeMMOSizePose = Player.pose
function Player:pose(...)
  local sprite, px, py, facing, phase, flip, hopping = previousPokeMMOSizePose(self, ...)
  if sprite and nativeDef(sprite.def) then decorateNativeRenderer(sprite) end
  return sprite, px, py, facing, phase, flip, hopping
end

local dramaticSpriteBillboards = dramaticModule("SpriteBillboards")
local dramaticVoxel3D = dramaticModule("Voxel3D")

local function clearCorrectedVoxelMeshes()
  for _, mesh in pairs(correctedVoxelMeshes) do
    if mesh and mesh.release then pcall(mesh.release, mesh) end
  end
  correctedVoxelMeshes = {}
end

local function cropForDef(def)
  if not nativeDef(def) then return nil end
  local okImage, image = pcall(Assets.image, def.image)
  if not (okImage and image) then return nil end
  return measureNativeCrop(def, image)
end

local function buildCorrectedVoxelCard(def, frame)
  if not (nativeDef(def) and dramaticVoxel3D
      and dramaticVoxel3D.newMesh and dramaticVoxel3D.pushQuad) then
    return nil
  end
  local crop = cropForDef(def)
  if not crop then return nil end

  local row = rowForEngineFrame(frame)
  local col = (tonumber(frame) or 0) >= 3 and nativeWalkColumn(1) or 0
  local species = def.dramaticSkyRideMountSpecies
  local mountScale = correctedMountScale(species)
  local scale = crop.fit * mountScale
  local key = table.concat({ tostring(def.image), tostring(frame), tostring(row),
    tostring(col), tostring(species), string.format("%.4f", scale),
    tostring(crop.left), tostring(crop.top), tostring(crop.width), tostring(crop.height) }, "#")
  if correctedVoxelMeshes[key] ~= nil then
    return correctedVoxelMeshes[key] or nil
  end

  local eps = 0.05
  local u0 = (col * crop.tileW + crop.left + eps) / crop.atlasW
  local u1 = (col * crop.tileW + crop.right - eps) / crop.atlasW
  local v0 = (row * crop.tileH + crop.top + eps) / crop.atlasH
  local v1 = (row * crop.tileH + crop.bottom - eps) / crop.atlasH
  local drawnW = crop.width * scale
  local drawnH = crop.height * scale
  local x0, x1 = 8 - drawnW / 2, 8 + drawnW / 2
  local verts = {
    { x0, 0,      0, u0, v1, 1 }, { x1, 0,      0, u1, v1, 1 },
    { x1, drawnH, 0, u1, v0, 1 }, { x0, drawnH, 0, u0, v0, 1 },
  }
  local indices = {}
  dramaticVoxel3D.pushQuad(indices, 0)
  local ok, mesh = pcall(dramaticVoxel3D.newMesh, verts, indices)
  correctedVoxelMeshes[key] = ok and mesh or false
  return ok and mesh or nil
end

-- Wrap outside main_38's billboard hook. Native PokeMMO definitions use the
-- corrected crop; every other sprite delegates to the already-installed chain.
if dramaticSpriteBillboards and dramaticVoxel3D
    and not dramaticSpriteBillboards.dramaticSkyRideOpaqueCropHook then
  local previousMesh = dramaticSpriteBillboards.mesh
  local previousShadowQuad = dramaticSpriteBillboards.shadowQuad

  if type(previousMesh) == "function" then
    dramaticSpriteBillboards.mesh = function(def, frame)
      if nativeDef(def) then
        return buildCorrectedVoxelCard(def, frame) or previousMesh(def, frame)
      end
      return previousMesh(def, frame)
    end
  end
  if type(previousShadowQuad) == "function" then
    dramaticSpriteBillboards.shadowQuad = function(def, frame)
      if nativeDef(def) then
        return buildCorrectedVoxelCard(def, frame) or previousShadowQuad(def, frame)
      end
      return previousShadowQuad(def, frame)
    end
  end
  dramaticSpriteBillboards.dramaticSkyRideOpaqueCropHook = true
end

mod.events:on("mod.options_changed", function(payload)
  if not payload then return end
  local key = tostring(payload.key or "")
  if payload.mod == "overworld_wild_spawns" and key == "sprite_style" then
    nativeCropCache = {}
    clearCorrectedVoxelMeshes()
  elseif payload.mod == mod.id
      and (key == "pokedex_mount_sizes" or key:match("^mount_size_")) then
    clearCorrectedVoxelMeshes()
  end
end)

mod.exports.nativePokeMMOSizeCorrection = {
  api = 1,
  heightMeters = actualPokedexHeight,
  scale = correctedMountScale,
  cropForDef = cropForDef,
}

log("native PokeMMO opaque-crop and Gen2 size correction loaded")
end)();
