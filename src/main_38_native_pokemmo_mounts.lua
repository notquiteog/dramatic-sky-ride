;(function()
-- -------------------------------------------------------------------------
-- Optional high-quality PokeMMO mount renderer for Wilds of Kanto.
--
-- Wilds normally converts its native 4x4 follow-sprite atlases (typically
-- 128x128 / 32px frames, with some 256x256 / 64px frames) into Gen1Recomp's
-- 16x96 six-frame walker format. That is perfect for ordinary followers, but
-- DSR then enlarges those already-downsampled 16px frames for large mounts.
--
-- When, and only when, Wilds' active sprite_style is exactly "pokemmo", DSR
-- can instead texture the mounted Pokemon directly from Wilds' native atlas.
-- Wilds' own wild/follower rendering is never modified. Any missing capability
-- or source asset falls straight back to the existing DSR/Wilds 16x96 path.
-- -------------------------------------------------------------------------
local WILDS_ID = "overworld_wild_spawns"
local PaletteFX = require("src.render.PaletteFX")
local nativeCache = {}
local nativeVoxelMeshes = {}

local function wildsExports()
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, WILDS_ID)
  return ok and handle and handle.exports or nil
end

local function wildsPokeMMOSelected()
  local ex = wildsExports()
  local render = ex and ex.render or nil
  local wildsMod = render and render.mod or nil
  local options = wildsMod and wildsMod.options or nil
  if not (options and type(options.get) == "function") then
    return false
  end
  local ok, style = pcall(options.get, options, "sprite_style")
  if not ok or type(style) ~= "string" then return false end
  return style:lower() == "pokemmo"
end

local function speciesDex(species)
  local cfg = (ELIGIBLE and ELIGIBLE[species])
    or (GROUND_ELIGIBLE and GROUND_ELIGIBLE[species])
  if cfg and tonumber(cfg.dex) then return math.floor(tonumber(cfg.dex)) end

  local pokemon = Game and Game.data and Game.data.pokemon or nil
  local def = pokemon and pokemon[species] or nil
  if def and tonumber(def.dex) then return math.floor(tonumber(def.dex)) end
  return nil
end

local function nativeAssetPath(rel)
  local ex = wildsExports()
  local render = ex and ex.render or nil
  if render and type(render._modAssetPath) == "function" then
    local ok, path = pcall(render._modAssetPath, render, rel)
    if ok and type(path) == "string" and path ~= "" then return path end
  end
  local wildsMod = render and render.mod or nil
  if wildsMod and wildsMod.assets and type(wildsMod.assets.path) == "function" then
    local ok, path = pcall(wildsMod.assets.path, wildsMod.assets, rel)
    if ok and type(path) == "string" and path ~= "" then return path end
  end
  return nil
end

local function mountScale(species)
  local fn = mod.exports and mod.exports.mountVisualScale or nil
  if type(fn) == "function" then
    local ok, value = pcall(fn, species)
    value = ok and tonumber(value) or nil
    if value and value > 0 then return value end
  end
  return 1
end

local function sourceAtlas(species)
  if not wildsPokeMMOSelected() then return nil end
  local dex = speciesDex(species)
  if not dex then return nil end

  local padded = string.format("%03d", dex)
  for _, form in ipairs({ "b", "m", "f" }) do
    local rel = string.format(
      "assets/enhanced_overworld/followsprites/%s-%s-n.png", padded, form)
    local path = nativeAssetPath(rel)
    if path then
      local ok, image = pcall(Assets.image, path)
      if ok and image and image.getDimensions then
        local w, h = image:getDimensions()
        if w == h and w >= 128 and w % 4 == 0 then
          if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
          return {
            path = path,
            image = image,
            width = w,
            height = h,
            tileW = w / 4,
            tileH = h / 4,
            dex = dex,
            form = form,
          }
        end
      end
    end
  end
  return nil
end

local function walkColumn(walkPhase)
  if tonumber(walkPhase) ~= 1 then return 0 end
  local ow = Game and Game.overworld or nil
  local player = ow and ow.player or nil
  local clock = tonumber(player and player.animClock) or 0
  -- Four source frames over the same 32-tick period used by DSR's existing
  -- two-pose walker, preserving cadence while exposing the native animation.
  return math.floor(clock / 8) % 4
end

local function rowForFacing(facing)
  -- Wilds/PokeMMO native atlas: down, left, right, up.
  if facing == "left" then return 1 end
  if facing == "right" then return 2 end
  if facing == "up" then return 3 end
  return 0
end

local function rowForEngineFrame(frame)
  frame = tonumber(frame) or 0
  if frame == 1 or frame == 4 then return 3 end -- up
  if frame == 2 or frame == 5 then return 1 end -- left; voxel pipeline mirrors right
  return 0 -- down
end

local function newNativeRenderer(species, atlas)
  local cacheKey = tostring(species) .. "|" .. tostring(atlas.path)
  if nativeCache[cacheKey] then return nativeCache[cacheKey] end

  local def = {
    id = "DSR_NATIVE_POKEMMO_" .. tostring(species),
    image = atlas.path,
    frames = 6,
    walker = true,
    trueColor = true,
    dramaticSkyRideMountSpecies = species,
    dramaticSkyRideNativePokeMMO = true,
    dramaticSkyRideNativeTileW = atlas.tileW,
    dramaticSkyRideNativeTileH = atlas.tileH,
    dramaticSkyRideNativeAtlasW = atlas.width,
    dramaticSkyRideNativeAtlasH = atlas.height,
  }

  local renderer = {
    def = def,
    image = atlas.image,
    frames = {},
    nativeQuads = {},
    nativePokeMMO = true,
  }

  local function quadFor(row, col)
    row = math.max(0, math.min(3, tonumber(row) or 0))
    col = math.max(0, math.min(3, tonumber(col) or 0))
    local key = row * 4 + col
    if not renderer.nativeQuads[key] then
      renderer.nativeQuads[key] = love.graphics.newQuad(
        col * atlas.tileW, row * atlas.tileH,
        atlas.tileW, atlas.tileH, atlas.width, atlas.height)
    end
    return renderer.nativeQuads[key]
  end

  -- Compatibility frames for code that only inspects renderer.frames. Actual
  -- 2D drawing below selects the full native four-frame animation dynamically.
  if love and love.graphics and love.graphics.newQuad then
    renderer.frames[0] = quadFor(0, 0)
    renderer.frames[1] = quadFor(3, 0)
    renderer.frames[2] = quadFor(1, 0)
    renderer.frames[3] = quadFor(0, 2)
    renderer.frames[4] = quadFor(3, 2)
    renderer.frames[5] = quadFor(1, 2)
  end

  function renderer:resolveImage()
    return self.image
  end

  function renderer:draw(px, py, camX, camY, facing, walkPhase, _stepFlip, _topHalf)
    if not (love and love.graphics and love.graphics.draw and love.graphics.newQuad) then
      return
    end
    local row = rowForFacing(facing)
    local col = walkColumn(walkPhase)
    local quad = quadFor(row, col)
    local visualScale = mountScale(species)
    local sx = (16 * visualScale) / atlas.tileW
    local sy = (16 * visualScale) / atlas.tileH

    -- Match DSR's existing 16px mount card foot anchor exactly: enlarging a
    -- Pokemon grows upward from the cell floor instead of drifting around its
    -- center. Source art is never bilinear-filtered.
    local x = math.floor((px or 0) - (camX or 0))
    local y = math.floor((py or 0) - (camY or 0)) - 4
    local anchorX, anchorY = x + 8, y + 16
    local drawnW, drawnH = atlas.tileW * sx, atlas.tileH * sy
    if PaletteFX and PaletteFX.markTrueColor then
      PaletteFX.markTrueColor(
        math.floor(anchorX - drawnW / 2), math.floor(anchorY - drawnH),
        math.ceil(drawnW), math.ceil(drawnH))
    end
    love.graphics.draw(self.image, quad, anchorX, anchorY,
      0, sx, sy, atlas.tileW / 2, atlas.tileH)
  end

  nativeCache[cacheKey] = renderer
  return renderer
end

local function nativeMountSprite(species)
  if not species or not wildsPokeMMOSelected() then return nil end
  local atlas = sourceAtlas(species)
  if not atlas then return nil end
  return newNativeRenderer(species, atlas)
end

-- Late Player:pose bridge keeps every existing lifecycle untouched. DSR stores
-- its normal 16x96 sprite as before; only the presentation returned for the
-- currently mounted player changes while Wilds is explicitly in PokeMMO mode.
local previousNativePokeMMOPose = Player.pose
function Player:pose(...)
  local sprite, px, py, facing, phase, flip, hopping = previousNativePokeMMOPose(self, ...)
  local ow = Game and Game.overworld or nil
  if not (ow and ow.player == self) then
    return sprite, px, py, facing, phase, flip, hopping
  end

  local species = nil
  if flight and flight.active then
    species = flight.species
  elseif ground and ground.active then
    species = ground.species
  else
    local waterActive = mod.exports and mod.exports.isWaterRiding
    local waterSpecies = mod.exports and mod.exports.waterMountSpecies
    if type(waterActive) == "function" and type(waterSpecies) == "function" then
      local okActive, active = pcall(waterActive)
      if okActive and active == true then
        local okSpecies, current = pcall(waterSpecies)
        if okSpecies then species = current end
      end
    end
  end

  if species then
    local native = nativeMountSprite(species)
    if native then
      return native, px, py, facing, phase, false, hopping
    end
  end
  return sprite, px, py, facing, phase, flip, hopping
end

-- Voxel providers do not call SpriteRenderer:draw; they ask SpriteBillboards
-- for a mesh using the returned sprite definition. Build an equivalent 16px
-- world card whose UVs point directly into the native 32/64px PokeMMO atlas.
-- The geometry keeps DSR's Pokédex size while retaining source texture detail.
local dramaticSpriteBillboards = dramaticModule("SpriteBillboards")
local dramaticVoxel3D = dramaticModule("Voxel3D")

local function clearNativeVoxelMeshes()
  for _, mesh in pairs(nativeVoxelMeshes) do
    if mesh and mesh.release then pcall(mesh.release, mesh) end
  end
  nativeVoxelMeshes = {}
end

local function buildNativeVoxelCard(def, frame)
  if not (def and def.dramaticSkyRideNativePokeMMO
      and dramaticVoxel3D and dramaticVoxel3D.newMesh and dramaticVoxel3D.pushQuad) then
    return nil
  end
  local okImage, image = pcall(Assets.image, def.image)
  if not (okImage and image) then return nil end
  local iw, ih = image:getDimensions()
  local tileW = tonumber(def.dramaticSkyRideNativeTileW) or (iw / 4)
  local tileH = tonumber(def.dramaticSkyRideNativeTileH) or (ih / 4)
  if tileW <= 0 or tileH <= 0 then return nil end

  local row = rowForEngineFrame(frame)
  local col = (tonumber(frame) or 0) >= 3 and walkColumn(1) or 0
  local species = def.dramaticSkyRideMountSpecies
  local scale = mountScale(species)
  local key = table.concat({ tostring(def.image), tostring(frame), tostring(row),
    tostring(col), tostring(species), string.format("%.4f", scale) }, "#")
  if nativeVoxelMeshes[key] ~= nil then
    return nativeVoxelMeshes[key] or nil
  end

  local eps = 0.05
  local u0 = (col * tileW + eps) / iw
  local u1 = ((col + 1) * tileW - eps) / iw
  local v0 = (row * tileH + eps) / ih
  local v1 = ((row + 1) * tileH - eps) / ih
  local halfW = 8 * scale
  local x0, x1 = 8 - halfW, 8 + halfW
  local y1 = 16 * scale
  local verts = {
    { x0, 0,  0, u0, v1, 1 }, { x1, 0,  0, u1, v1, 1 },
    { x1, y1, 0, u1, v0, 1 }, { x0, y1, 0, u0, v0, 1 },
  }
  local indices = {}
  dramaticVoxel3D.pushQuad(indices, 0)
  local ok, mesh = pcall(dramaticVoxel3D.newMesh, verts, indices)
  nativeVoxelMeshes[key] = ok and mesh or false
  return ok and mesh or nil
end

if dramaticSpriteBillboards and dramaticVoxel3D
    and not dramaticSpriteBillboards.dramaticSkyRideNativePokeMMOHook then
  local previousMesh = dramaticSpriteBillboards.mesh
  local previousShadowQuad = dramaticSpriteBillboards.shadowQuad

  if type(previousMesh) == "function" then
    dramaticSpriteBillboards.mesh = function(def, frame)
      if def and def.dramaticSkyRideNativePokeMMO then
        return buildNativeVoxelCard(def, frame) or previousMesh(def, frame)
      end
      return previousMesh(def, frame)
    end
  end

  if type(previousShadowQuad) == "function" then
    dramaticSpriteBillboards.shadowQuad = function(def, frame)
      if def and def.dramaticSkyRideNativePokeMMO then
        return buildNativeVoxelCard(def, frame) or previousShadowQuad(def, frame)
      end
      return previousShadowQuad(def, frame)
    end
  end

  dramaticSpriteBillboards.dramaticSkyRideNativePokeMMOHook = true
  if Assets.register then Assets.register(clearNativeVoxelMeshes) end
end

mod.events:on("mod.options_changed", function(payload)
  if not payload then return end
  if payload.mod == WILDS_ID and payload.key == "sprite_style" then
    clearNativeVoxelMeshes()
  elseif payload.mod == mod.id then
    local key = tostring(payload.key or "")
    if key == "pokedex_mount_sizes" or key:match("^mount_size_") then
      clearNativeVoxelMeshes()
    end
  end
end)

mod.exports.nativePokeMMOMounts = {
  api = 1,
  active = wildsPokeMMOSelected,
  resolve = nativeMountSprite,
  sourceDex = speciesDex,
}

log("optional native PokeMMO mount renderer loaded")
end)();
