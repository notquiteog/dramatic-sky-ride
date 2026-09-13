    if mountOption("ground_dust", true) and ground.gallop
       and (ground.dustDistance or 0) >= 20
       and not (ground.amphibiousWater == true)
       and self.startDustAnim and not self.dustAnim then
      ground.dustDistance = 0
      pcall(self.startDustAnim, self, self.player.cellX, self.player.cellY)
    end
    ensureGroundRiderEntity(self)
    if ground.riderEntity then
      ground.riderEntity.pose = groundRiderPose
      ground.riderEntity.draw = groundRiderDraw
    end
  end
  return result
end

-- Ground Ride HUD.
local polishDrawUI = OverworldState.drawUI
function OverworldState:drawUI(...)
  local result = polishDrawUI(self, ...)
  if not (ground.active and Game.overworld == self and love and love.graphics) then return result end
  local showGauge = mountOption("ground_hud", true)
    and ((ground.speedBlend or 0) > 0.02 or (ground.stamina or 1) < 0.999)
  if not showGauge and not ground.notice then return result end
  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, 1)
  if showGauge then
    Font.drawBox(9, 0, 11, 4)
    Font.draw("RIDE", 80, 8)
    local level = math.floor(clamp(ground.stamina or 0, 0, 1) * 5 + 0.5)
    for i = 1, 5 do
      local x, y = 80 + (i - 1) * 13, 21
      love.graphics.rectangle("line", x + 0.5, y + 0.5, 9, 5)
      if i <= level then love.graphics.rectangle("fill", x + 2, y + 2, 6, 2) end
    end
  end
  if ground.notice then
    Font.drawBox(1, 14, 18, 4)
    Font.draw(ground.notice, math.floor((160 - Font.width(ground.notice)) / 2), 120)
  end
  love.graphics.pop()
  return result
end

-- Visible Surf mounts ---------------------------------------------------------
local WATER_ELIGIBLE = {
  BLASTOISE = { dex = 9, label = "BLASTOISE", lift = 7.0 },
  TENTACRUEL = { dex = 73, label = "TENTACRUEL", lift = 6.0 },
  GYARADOS = { dex = 130, label = "GYARADOS", lift = 7.0 },
  LAPRAS = { dex = 131, label = "LAPRAS", lift = 7.5 },
  FERALIGATR = { dex = 160, label = "FERALIGATR", lift = 7.3 },
  MANTINE = { dex = 226, label = "MANTINE", lift = 6.6 },
  KINGDRA = { dex = 230, label = "KINGDRA", lift = 6.8 },
  LUGIA = { dex = 249, label = "LUGIA", lift = 8.0 },
}
local WATER_BY_DEX = {}
for species, cfg in pairs(WATER_ELIGIBLE) do WATER_BY_DEX[cfg.dex] = species end
local water = { active = false, species = nil, mon = nil, sprite = nil,
  riderSprite = nil, riderEntity = nil, source = nil, lastFailure = nil }
local lastWaterMountIndex = nil
local waterBattleResume = nil
local waterSpriteCache = {}

local function waterSpecies(game, mon)
  if not (game and mon) then return nil end
  if WATER_ELIGIBLE[mon.species] then return mon.species end
  local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
  local dex = def and tonumber(def.dex)
  return dex and WATER_BY_DEX[dex] or nil
end

local function monKnowsMove(mon, moveId)
  for _, move in ipairs(mon and mon.moves or {}) do
    local id = type(move) == "table" and move.id or move
    if id == moveId then return true end
  end
  return false
end

local function genericFollowerPath(cfg)
  if not cfg or not (love and love.filesystem and love.filesystem.getDirectoryItems) then return nil end
  local filename = string.format("follower_%03d.png", cfg.dex)
  local ok, names = pcall(love.filesystem.getDirectoryItems, "mods")
  if not ok or type(names) ~= "table" then return nil end
  local fallback
  for _, name in ipairs(names) do
    local root = "mods/" .. name
    local asset = root .. "/assets/sprites/" .. filename
    if fileExists(asset) then
      local raw = love.filesystem.read(root .. "/manifest.json")
      local id = manifestId(raw)
      if id and FOLLOWER_IDS[id] then return asset end
      fallback = fallback or asset
    end
  end
  return fallback
end

local function buildWaterRenderer(species, path, source, trueColor)
  if not path then return nil, "missing_path" end
  local okImage, image = pcall(Assets.image, path)
  if not okImage or not image then return nil, "image_load_failed" end
  setNearest(image)
  local w, h = image:getDimensions()

  -- Visible Surf uses the same six 16x16 facing frames as Gen1Recomp's
  -- SpriteRenderer. Providers may expose PokeMMO/other enlarged sheets for
  -- ordinary followers; accepting one here turns the whole sheet into one
  -- giant malformed Surf card. Use only the canonical mount-safe layout.
  if w ~= 16 or h ~= 96 then
    return nil, string.format("unsafe_sheet_%dx%d", tonumber(w) or 0, tonumber(h) or 0)
  end

  local def = {
    id = "WATER_RIDE_" .. species,
    image = path,
    frames = 6,
    walker = true,
    trueColor = trueColor ~= false,
    dramaticSkyRideWaterMount = true,
    dramaticSkyRideMountSpecies = species,
    skyRideSpriteProvider = source,
  }
  local sprite = SpriteRenderer.new(def, "water_ride_" .. species)
  sprite.image = image
  return sprite
end

local function publicWaterMountSprite(species)
  if not mod.find then return nil, "provider_api_unavailable" end
  local cfg = WATER_ELIGIBLE[species]
  local dex = cfg and cfg.dex or nil
  local providerIds = {
    "overworld_wild_spawns",
    "PokePCFollowers_VoxelMerge",
    "pokepcfollowers",
    "FOLLOWERS_EX",
    "followers_ex",
  }
  local lastReason = "no_provider_sprite"
  for _, providerId in ipairs(providerIds) do
    local okFind, handle = pcall(mod.find, mod, providerId)
    local exports = okFind and handle and handle.exports or nil
    if exports and type(exports.resolveFollowerSprite) == "function" then
      -- Water art is preferred when a provider has a dedicated canonical
      -- follower sheet. Land/follower is a safe second request because many
      -- providers expose only one six-frame overworld strip.
      local requests = {
        { surface = "water" },
        { surface = "land", style = providerId == "overworld_wild_spawns" and "followers" or nil },
      }
      for _, request in ipairs(requests) do
        local okDef, provided = pcall(exports.resolveFollowerSprite, {
          species = species,
          dex = dex,
          surface = request.surface,
          style = request.style,
          role = "surf_mount",
          game = Game,
        })
        if okDef and provided and provided.image and tonumber(provided.frames) == 6 then
          local sprite, reason = buildWaterRenderer(species, provided.image,
            provided.providerId or providerId, provided.trueColor)
          if sprite then return sprite, nil end
          lastReason = tostring(reason)
        elseif okDef and provided and provided.image then
          lastReason = "provider_frames_" .. tostring(provided.frames)
        end
      end
    end
  end
  return nil, lastReason
end

local function buildWaterSprite(species)
  if waterSpriteCache[species] then
    water.source = "cache"
    water.lastFailure = nil
    return waterSpriteCache[species]
  end

  local cfg = WATER_ELIGIBLE[species]

  -- Prefer the raw dex-numbered follower strip when it exists. It is the
  -- stable 16x96 contract DSR's Flight/Ground paths already rely on and is
  -- deliberately independent of a provider's currently selected visual mode.
  local path = genericFollowerPath(cfg)
  if path then
    local sprite, reason = buildWaterRenderer(species, path, "dex_follower_asset", true)
    if sprite then
      waterSpriteCache[species] = sprite
      water.source = "dex_follower_asset"
      water.lastFailure = nil
      return sprite
    end
    water.lastFailure = reason
  end

  local provided, reason = publicWaterMountSprite(species)
  if provided then
    waterSpriteCache[species] = provided
    water.source = provided.def and provided.def.skyRideSpriteProvider or "provider"
    water.lastFailure = nil
    return provided
  end

  water.source = nil
  water.lastFailure = reason or water.lastFailure or "missing_mount_sprite"
  return nil
end

local function preferredWaterMount(game, requested)
  local party = game and game.save and game.save.party or {}
  if requested and healthy(requested) and waterSpecies(game, requested)
     and monKnowsMove(requested, "SURF") then return requested end
  if lastWaterMountIndex and healthy(party[lastWaterMountIndex])
     and waterSpecies(game, party[lastWaterMountIndex])
     and monKnowsMove(party[lastWaterMountIndex], "SURF") then
    return party[lastWaterMountIndex]
  end
  for i, mon in ipairs(party) do
    if healthy(mon) and waterSpecies(game, mon) and monKnowsMove(mon, "SURF") then
      lastWaterMountIndex = i
      return mon
    end
  end
end

local function removeWaterRider(ow)
  if not water.riderEntity then return end
  if ow then
    removeFromList(ow.entities, water.riderEntity)
    removeFromList(ow.npcs, water.riderEntity)
  end
  water.riderEntity = nil
end

local function waterRiderPose(entity)
  local ow, p = Game.overworld, Game.overworld and Game.overworld.player
  if not (water.active and p and water.riderSprite) then
    return entity.sprite, entity.px or 0, entity.py or 0, entity.facing or "down", 0, false, false
  end
  local cfg = WATER_ELIGIBLE[water.species] or { lift = 7 }
  entity.cellX, entity.cellY, entity.px, entity.py, entity.facing = p.cellX, p.cellY, p.px, p.py, p.facing
  local phase = math.floor((p.animClock or 0) / 16) % 2
  return water.riderSprite, p.px, p.py - cfg.lift, p.facing, phase, false, false
end

local function waterRiderDraw(entity, camX, camY)
  local sprite, px, py, facing, phase, flip = waterRiderPose(entity)
  if sprite and sprite.draw then sprite:draw(px, py, camX, camY, facing, phase, flip) end
end

local function ensureWaterRider(ow)
  if not (water.active and ow and ow.player and water.riderSprite) or isFirstPerson() then
    removeWaterRider(ow)
    return
  end
  local e = water.riderEntity
  if not e then
    e = { id = "water_ride_rider", waterRideRider = true, passable = true,
      sprite = water.riderSprite, pose = waterRiderPose, draw = waterRiderDraw }
    water.riderEntity = e
  end
  waterRiderPose(e)
  if not contains(ow.entities, e) then table.insert(ow.entities, e) end
end

local function clearWaterRide(ow)
  removeWaterRider(ow)
  water.active, water.species, water.mon = false, nil, nil
  water.sprite, water.riderSprite = nil, nil
end
