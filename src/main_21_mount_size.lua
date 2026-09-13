-- alpha.15.3: Pokédex-proportional mount sizing with per-species overrides.
-- Visual scale only: logical cells, collision, movement and encounter rules stay
-- unchanged. A 1.70 m Pokémon maps to the original 16 px overworld card.
;(function()
  local PaletteFX = require("src.render.PaletteFX")

  local POKEDEX_REFERENCE_METERS = 1.70
  local MIN_CANONICAL_SCALE = 0.50
  local MAX_CANONICAL_SCALE = 4.00
  local MIN_USER_PERCENT = 50
  local MAX_USER_PERCENT = 200
  local USER_STEP_PERCENT = 5

  local MOUNT_SIZE_SPECIES = {
    -- Flying
    "CHARIZARD", "PIDGEOT", "FEAROW", "GOLBAT", "AERODACTYL",
    "ARTICUNO", "ZAPDOS", "MOLTRES", "DRAGONAIR", "DRAGONITE",
    -- Ground Ride
    "ARCANINE", "RAPIDASH", "DODRIO", "RHYHORN", "RHYDON",
    "KANGASKHAN", "TAUROS", "SNORLAX",
    -- Visible Surf
    "BLASTOISE", "TENTACRUEL", "GYARADOS", "LAPRAS",
  }

  local function sizeOptionKey(species)
    return "mount_size_" .. tostring(species):lower()
  end

  -- The normal Gen1Recomp option UI supports numeric rows, so each species can
  -- be tuned independently without adding a second custom settings screen.
  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = {
    key = "pokedex_mount_sizes",
    type = "toggle",
    label = "POKEDEX SIZES",
    default = true,
    help = "Scale mount sprites from each Pokemon's Pokedex height.",
  }
  for _, species in ipairs(MOUNT_SIZE_SPECIES) do
    OPTION_SCHEMA[#OPTION_SCHEMA + 1] = {
      key = sizeOptionKey(species),
      type = "number",
      label = "SIZE " .. species,
      default = 100,
      min = MIN_USER_PERCENT,
      max = MAX_USER_PERCENT,
      step = USER_STEP_PERCENT,
      help = "100 keeps this mount at its Pokedex-derived size.",
    }
  end
  if mod.options and mod.options.define then
    mod.options:define(OPTION_SCHEMA)
  end

  local function mountDexNumber(species)
    -- WATER_ELIGIBLE lives inside the alpha.15 polish scope and is not
    -- lexically visible here. Resolve known flight/ground mounts first, then
    -- fall back to the canonical Pokemon definition so Surf species work
    -- without reaching into another chunk's private locals.
    local cfg = ELIGIBLE[species] or GROUND_ELIGIBLE[species]
    if cfg and cfg.dex then return tonumber(cfg.dex) end
    local pokemon = Game.data and Game.data.pokemon
    local def = pokemon and pokemon[species]
    return def and tonumber(def.dex) or nil
  end

  local function mountPokemonDef(species)
    local pokemon = Game.data and Game.data.pokemon
    if type(pokemon) ~= "table" then return nil end
    if pokemon[species] then return pokemon[species] end
    local dex = mountDexNumber(species)
    if not dex then return nil end
    for _, def in pairs(pokemon) do
      if type(def) == "table" and tonumber(def.dex) == dex then return def end
    end
    return nil
  end

  local function pokedexHeightMeters(species)
    local def = mountPokemonDef(species)
    local entry = def and def.dexEntry
    local ft = entry and tonumber(entry.heightFt)
    local inch = entry and tonumber(entry.heightIn)
    if not ft or not inch then return nil end
    local totalInches = ft * 12 + inch
    if totalInches <= 0 then return nil end
    return totalInches * 0.0254
  end

  local function canonicalMountScale(species)
    if optionValue("pokedex_mount_sizes", true) ~= true then return 1 end
    local meters = pokedexHeightMeters(species)
    if not meters then return 1 end
    return clamp(meters / POKEDEX_REFERENCE_METERS,
      MIN_CANONICAL_SCALE, MAX_CANONICAL_SCALE)
  end

  local function mountVisualScale(species)
    if not species then return 1 end
    local percent = tonumber(optionValue(sizeOptionKey(species), 100)) or 100
    percent = clamp(percent, MIN_USER_PERCENT, MAX_USER_PERCENT)
    return canonicalMountScale(species) * percent / 100
  end

  -- Late compatibility layers can provide missing Pokedex heights (notably
  -- Gold's Johto roster). Resolve the public function at draw time so the 2D
  -- card, rider seat and voxel billboard all use the same final scale.
  local function effectiveMountVisualScale(species)
    local current = mod.exports and mod.exports.mountVisualScale or nil
    if type(current) == "function" and current ~= mountVisualScale then
      local ok, value = pcall(current, species)
      value = ok and tonumber(value) or nil
      if value and value > 0 then return value end
    end
    return mountVisualScale(species)
  end

  -- Mount sprites use true-color follower sheets. Draw the chosen frame
  -- directly so the scale pivots around the feet while PaletteFX receives the
  -- actual enlarged/shrunk screen rect. This keeps 2D palette masking correct.
  local function decorateMountSprite(sprite, species)
    if not (sprite and sprite.def) then return sprite end
    if sprite.def.dramaticSkyRideMountSpecies then return sprite end
    sprite.def.dramaticSkyRideMountSpecies = species

    local rawDraw = sprite.draw
    sprite.draw = function(self, px, py, camX, camY, facing, walkPhase,
                           stepFlip, topHalf)
      local scale = effectiveMountVisualScale(species)
      if topHalf or math.abs(scale - 1) < 0.0001
         or not (love and love.graphics and love.graphics.draw) then
        return rawDraw(self, px, py, camX, camY, facing, walkPhase,
                       stepFlip, topHalf)
      end

      local def = self.def or {}
      local frame = 0
      if (def.frames or 1) > 1 then
        frame = (def.walker and walkPhase == 1)
          and SpriteRenderer.WALK[facing] or SpriteRenderer.STAND[facing]
      end
      local mirror = facing == "right"
        or ((facing == "down" or facing == "up")
          and walkPhase == 1 and stepFlip)
      local quad = self.frames and (self.frames[frame] or self.frames[0])
      if not quad then
        return rawDraw(self, px, py, camX, camY, facing, walkPhase,
                       stepFlip, topHalf)
      end

      local x = math.floor((px or 0) - (camX or 0))
      local y = math.floor((py or 0) - (camY or 0)) - 4
      local anchorX, anchorY = x + 8, y + 16
      local w, h = 16 * scale, 16 * scale
      if def.trueColor and PaletteFX.markTrueColor then
        PaletteFX.markTrueColor(math.floor(anchorX - w / 2),
          math.floor(anchorY - h), math.ceil(w), math.ceil(h))
      end
      local sx = mirror and -scale or scale
      love.graphics.draw(self.image, quad, anchorX, anchorY,
                         0, sx, scale, 8, 16)
    end
    return sprite
  end

  -- Every path which creates a mount now receives the same scale metadata.
  -- Battle restoration and map transitions also rebuild through these helpers,
  -- so the setting survives all existing lifecycle paths.
  local rawBuildMountSprite = buildMountSprite
  buildMountSprite = function(species, ...)
    local sprite, reason = rawBuildMountSprite(species, ...)
    return decorateMountSprite(sprite, species), reason
  end

  local rawBuildGroundMountSprite = buildGroundMountSprite
  buildGroundMountSprite = function(species, ...)
    local sprite, reason = rawBuildGroundMountSprite(species, ...)
    return decorateMountSprite(sprite, species), reason
  end

  -- Visible Surf's builder is private to the alpha.15 polish scope. Do not
  -- install a global wrapper around a nil symbol: that polluted the runtime
  -- and could turn a later external call into a hard error. Surf sizing will
  -- use its dedicated bridge when that private path is refactored.

  -- Keep the trainer seated at the same relative point on a resized card. The
  -- trainer itself deliberately remains human-sized; only its seat height
  -- follows the Pokémon visual scale.
  local rawFlightRiderPose = riderPose
  riderPose = function(entity)
    local sprite, px, py, facing, phase, flip, hopping = rawFlightRiderPose(entity)
    if flight.active and flight.species then
      local cfg = RIDER_OFFSETS[flight.species] or DEFAULT_RIDER_OFFSET
      py = py - (tonumber(cfg.lift) or DEFAULT_RIDER_OFFSET.lift)
        * (effectiveMountVisualScale(flight.species) - 1)
    end
    return sprite, px, py, facing, phase, flip, hopping
  end

  -- main_17 keeps GROUND_PROFILES private inside its polish closure. The old
  -- size wrapper accidentally indexed a global GROUND_PROFILES (nil) as soon
  -- as Ground Ride mounted, which crashed on the first rider-pose evaluation.
  -- Mirror only the seat heights we need here instead of depending on a
  -- private table from another lexical scope.
  local GROUND_RIDER_LIFT = {
    ARCANINE = 6.8, RAPIDASH = 7.1, DODRIO = 7.2, RHYHORN = 6.2,
    RHYDON = 7.4, KANGASKHAN = 7.8, TAUROS = 6.7, SNORLAX = 8.6,
  }
  local rawGroundRiderPoseForSize = groundRiderPose
  groundRiderPose = function(entity)
    local sprite, px, py, facing, phase, flip, hopping =
      rawGroundRiderPoseForSize(entity)
    if ground.active and ground.species then
      local lift = GROUND_RIDER_LIFT[ground.species] or 6.5
      py = py - lift * (effectiveMountVisualScale(ground.species) - 1)
    end
    return sprite, px, py, facing, phase, flip, hopping
  end

  -- WATER_ELIGIBLE, water and waterRiderPose are intentionally private to
  -- main_17's polish closure. The previous code created unrelated globals
  -- here and therefore never affected the real Surf rider. Leave that private
  -- path alone rather than installing wrappers around nil symbols.

  -- Dramatic Shape does not call SpriteRenderer:draw in voxel mode: it builds
  -- a 16x16 billboard mesh from sprite.def. Replace only the billboard methods
  -- for our tagged mount definitions, leaving every other Dramatic Shape sprite
  -- exactly untouched.
  local scaledVoxelMeshes = {}
  local dramaticSpriteBillboards = dramaticModule("SpriteBillboards")
  local dramaticVoxel3D = dramaticModule("Voxel3D")

  local function clearScaledVoxelMeshes()
    for _, mesh in pairs(scaledVoxelMeshes) do
      if mesh and mesh.release then pcall(mesh.release, mesh) end
    end
    scaledVoxelMeshes = {}
  end

  local function buildScaledVoxelCard(def, frame, scale)
    if not (dramaticVoxel3D and dramaticVoxel3D.newMesh
            and dramaticVoxel3D.pushQuad) then return nil end
    local okImage, img = pcall(Assets.image, def.image)
    if not (okImage and img) then return nil end
    local iw, ih = img:getDimensions()
    local fy = (tonumber(frame) or 0) * 16
    if fy + 16 > ih then fy = 0 end
    local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
    local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
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
    return ok and mesh or nil
  end

  if dramaticSpriteBillboards and dramaticVoxel3D
     and not dramaticSpriteBillboards.dramaticSkyRideSizeHook then
    local rawMesh = dramaticSpriteBillboards.mesh
    local rawShadowQuad = dramaticSpriteBillboards.shadowQuad

    local function scaledMesh(def, frame, fallback)
      local species = def and def.dramaticSkyRideMountSpecies
      if not species then return fallback(def, frame) end
      local scale = effectiveMountVisualScale(species)
      if math.abs(scale - 1) < 0.0001 then return fallback(def, frame) end
      local key = table.concat({ tostring(def.image), tostring(frame),
        tostring(species), string.format("%.4f", scale) }, "#")
      if scaledVoxelMeshes[key] == nil then
        scaledVoxelMeshes[key] = buildScaledVoxelCard(def, frame, scale) or false
      end
      return scaledVoxelMeshes[key] or fallback(def, frame)
    end

    dramaticSpriteBillboards.mesh = function(def, frame)
      return scaledMesh(def, frame, rawMesh)
    end
    dramaticSpriteBillboards.shadowQuad = function(def, frame)
      return scaledMesh(def, frame, rawShadowQuad)
    end
    dramaticSpriteBillboards.dramaticSkyRideSizeHook = true

    if Assets.register then Assets.register(clearScaledVoxelMeshes) end
  end

  mod.events:on("mod.options_changed", function(payload)
    if not (payload and payload.mod == mod.id) then return end
    local key = tostring(payload.key or "")
    if key == "pokedex_mount_sizes" or key:match("^mount_size_") then
      clearScaledVoxelMeshes()
    end
  end)

  -- Small public inspection surface useful for compatibility/debug tools.
  mod.exports.mountVisualScale = mountVisualScale
  mod.exports.mountPokedexHeightMeters = pokedexHeightMeters

  log("alpha.15.3 Pokedex-proportional mount sizing loaded")
end)()
