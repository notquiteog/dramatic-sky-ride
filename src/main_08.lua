    entity.px, entity.py = p.px, p.py
  end
  return entity.sprite, entity.px or 0, entity.py or 0,
         "down", 0, false, false
end

local function groundFxDraw(entity, camX, camY)
  local sprite, px, py, facing, phase, flip = groundFxPose(entity)
  if sprite and sprite.draw then
    sprite:draw(px, py, camX, camY, facing, phase, flip)
  end
end

local function removeGroundFxEntity(ow)
  local entity = flight.groundFxEntity
  if not entity then return end
  if ow then
    removeFromList(ow.entities, entity)
    removeFromList(ow.npcs, entity)
  end
end

local function redrawGroundFx(ow)
  local sprite = flight.groundFxSprite
  local canvas = sprite and sprite.image
  if not (canvas and love and love.graphics) then return end
  local p = ow and ow.player
  if not p then return end
  local ground = terrainGroundHeight(ow.map, p.cellX, p.cellY)
  local relative = math.max(0, (flight.altitude or 0) - ground)
  local t = clamp(relative / MAX_MANUAL_HEIGHT, 0, 1)
  local valid = landingCellValid and landingCellValid(ow, p.cellX, p.cellY)
  local markerVisible = landingMarkerEnabled()
    and (relative <= GROUND_FX_VISIBLE_HEIGHT
         or flight.phase == "landing" or (flight.verticalInput or 0) < 0
         or flight.notice ~= nil)

  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  for frame = 0, 5 do
    local oy = frame * 16
    if dynamicShadowEnabled() then
      local rx = 4 + 3 * t
      local ry = 1.4 + 0.8 * t
      local alpha = 0.48 - 0.30 * t
      love.graphics.setColor(0, 0, 0, alpha)
      love.graphics.ellipse("fill", 8, oy + 13, rx, ry)
    end
    if markerVisible then
      if valid then love.graphics.setColor(0.20, 1.00, 0.35, 0.90)
      else love.graphics.setColor(1.00, 0.20, 0.20, 0.90) end
      love.graphics.ellipse("line", 8, oy + 12, 6, 2.8)
      if not valid then
        love.graphics.line(4, oy + 10, 12, oy + 14)
        love.graphics.line(12, oy + 10, 4, oy + 14)
      end
    end
  end
  love.graphics.setCanvas()
  love.graphics.pop()
end

local function ensureGroundFxEntity(ow)
  if not (flight.active and ow and ow.player
          and (dynamicShadowEnabled() or landingMarkerEnabled())) then
    removeGroundFxEntity(ow)
    return nil
  end
  if not flight.groundFxSprite then
    flight.groundFxSprite = buildGroundFxSprite()
  end
  if not flight.groundFxSprite then return nil end
  local entity = flight.groundFxEntity
  if not entity then
    entity = {
      id = "sky_ride_ground_fx", skyRideGroundFx = true,
      passable = true, sprite = flight.groundFxSprite,
      pose = groundFxPose, draw = groundFxDraw,
    }
    flight.groundFxEntity = entity
  end
  entity.sprite = flight.groundFxSprite
  groundFxPose(entity)
  redrawGroundFx(ow)
  if not contains(ow.entities, entity) then table.insert(ow.entities, 1, entity) end
  return entity
end

-- PokePC Followers uses the native Pikachu follower entity and annotates it
-- with _pokepcFollowerSpecies. Followers EX can add several trailer NPCs,
-- marked with pokepcTrailer / pokepcMon. Test every known marker rather than
-- relying only on SPRITE_PIKACHU, so the whole ground party disappears while
-- the player is mounted.
local function isFollowerEntity(e, player)
  if not e or e == player then return false end
  local spriteDef = e.sprite and e.sprite.def
  local defId = spriteDef and spriteDef.id
  local id = tostring(e.id or ""):lower()
  local spriteId = tostring(e.spriteId or defId or ""):upper()
  return e.pikachuFollower == true
      or e.pokepcTrailer == true
      or e.pokepcMon ~= nil
      or e._pokepcFollowerSpecies ~= nil
      or id == "pikachu"
      or id:find("pokepc", 1, true) ~= nil
      or spriteId == "SPRITE_PIKACHU"
      or spriteId:find("POKEPC", 1, true) ~= nil
end

local function removeFollowersFromList(list, player, captured)
  for i = #(list or {}), 1, -1 do
    local e = list[i]
    if isFollowerEntity(e, player) then
      if captured and not contains(captured, e) then
        captured[#captured + 1] = e
      end
      table.remove(list, i)
    end
  end
end

local function purgeFollowersDuringFlight(ow, captured)
  if not ow then return end
  captured = captured or {}
  captured.entities = captured.entities or {}
  captured.npcs = captured.npcs or {}
  removeFollowersFromList(ow.entities, ow.player, captured.entities)
  removeFollowersFromList(ow.npcs, ow.player, captured.npcs)
  return captured
end

local function suspendFollowers(ow)
  local out = { mapId = ow.map and ow.map.id, entities = {}, npcs = {} }
  return purgeFollowersDuringFlight(ow, out)
end

local FOLLOWER_MOD_IDS = {
  "FOLLOWERS_EX",
  "followers_ex",
  "PokePCFollowers_VoxelMerge",
  "pokepcfollowers",
}

local function hasFollowerEntity(ow)
  if not ow then return false end
  for _, list in ipairs({ ow.entities or {}, ow.npcs or {} }) do
    for _, e in ipairs(list) do
      if isFollowerEntity(e, ow.player) then return true end
    end
  end
  return false
end

local function syncFollowerMods(ow)
  if PikachuFollower and type(PikachuFollower.onMapEntered) == "function" then
    pcall(PikachuFollower.onMapEntered, Game, ow, {})
  end
  if mod.find then
