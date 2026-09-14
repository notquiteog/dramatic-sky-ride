    if declaredFrames then sourceFrames = math.min(sourceFrames, declaredFrames) end
    local out = love.image.newImageData(16, 96)
    for frame = 0, 5 do
      local sourceFrame = math.min(frame, sourceFrames - 1)
      for y = 0, RIDER_CROP_HEIGHT - 1 do
        for x = 0, 15 do
          out:setPixel(x, frame * 16 + RIDER_CROP_Y + y,
                       src:getPixel(x, sourceFrame * 16 + y))
        end
      end
    end
    riderData[path] = out
    if src.release then src:release() end
    return path
  end)
  if not ok then return nil, result end
  return result
end

end -- runtime rider asset scope

local function buildRiderSprite(player)
  local sourceSprite = mod.exports._riderSourceSprite(player)
  if not sourceSprite then return nil, "player_sprite_missing" end
  local path, reason = writeRiderSheet(player, sourceSprite)
  if not path then
    -- An unusual port without CPU-readable image data keeps the player
    -- visible through the original palette-aware renderer.
    return sourceSprite, "uncropped_fallback:" .. tostring(reason)
  end
  -- Verify the same asset seam SpriteRenderer and Battle Art use. A custom
  -- host without the generated-image bridge retains the native fallback.
  do
    local okAssets, RenderAssets = pcall(require, "src.render.Assets")
    if okAssets and RenderAssets and type(RenderAssets.image) == "function" then
      local okRead, image = pcall(RenderAssets.image, path)
      if not (okRead and image) then
        return sourceSprite,
          "uncropped_fallback:engine_cannot_read_runtime_sheet"
      end
    end
  end
  local sourceDef = sourceSprite.def or {}
  local def = shallowCopy(sourceDef)
  def.id = "SKY_RIDE_RIDER_" .. safeAssetName(sourceDef.id)
  def.image = path
  def.frames = 6
  def.walker = true
  local sprite = SpriteRenderer.new(def,
    "sky_ride_rider:" .. tostring(sourceDef.id or sourceDef.image))
  -- Gold assigns the live player's CGB OBJ palette to the renderer instance,
  -- not to spriteDef. The cropped rider is a new instance, so carry that
  -- palette across explicitly or Chris is drawn in the fallback grey ramp.
  if sourceSprite.objColors and type(sprite.setObjPalette) == "function" then
    sprite:setObjPalette(sourceSprite.objColors, sourceSprite.objGroup)
  end
  return sprite
end

local function contains(t, value)
  for _, item in ipairs(t or {}) do
    if item == value then return true end
  end
  return false
end

local function removeFromList(list, value)
  for i = #(list or {}), 1, -1 do
    if list[i] == value then table.remove(list, i) end
  end
end

local function riderWorldOffset(player)
  local cfg = RIDER_OFFSETS[flight.species] or DEFAULT_RIDER_OFFSET
  if isThirdPerson() then
    local d = FACING_DELTA[player.facing] or FACING_DELTA.down
    -- The 3RD eye sits behind the player. Pulling the rider a fraction of a
    -- pixel toward that eye prevents coplanar transparency flicker.
    return -d[1] * cfg.depth, -d[2] * cfg.depth
  end
  return cfg.orbitX or 0, cfg.orbitY or 0.3
end

local function syncRiderTransform(entity, player)
  if not (entity and player) then return end
  local dx, dy = riderWorldOffset(player)
  entity.cellX, entity.cellY = player.cellX, player.cellY
  entity.targetX, entity.targetY = nil, nil
  entity.px, entity.py = player.px + dx, player.py + dy
  entity.facing = player.facing
end

local function riderPose(entity)
  local ow = Game.overworld
  local player = ow and ow.player
  if not (flight.active and player and flight.riderSprite) then
    return entity.sprite, entity.px or 0, entity.py or 0,
           entity.facing or "down", 0, false, false
  end
  syncRiderTransform(entity, player)
  local cfg = RIDER_OFFSETS[flight.species] or DEFAULT_RIDER_OFFSET
  local ground = terrainGroundHeight(ow.map, player.cellX, player.cellY)
  local mountLift = math.max(0, flight.altitude - ground)
  local flip = math.floor((player.animClock or 0) / 16) % 2 == 1
  return flight.riderSprite, entity.px,
         entity.py - mountLift - cfg.lift,
         player.facing, 0, flip, false
end

local function riderDraw(entity, camX, camY)
  local sprite, px, py, facing, phase, flip = riderPose(entity)
  if sprite and sprite.draw then
    sprite:draw(px, py, camX, camY, facing, phase, flip)
  end
end

local function removeRiderEntity(ow)
  local entity = flight.riderEntity
  local function purge(list)
    if type(list) ~= "table" then return end
    for i = #list, 1, -1 do
      local candidate = list[i]
      if candidate == entity
         or (type(candidate) == "table" and candidate.skyRideRider) then
        table.remove(list, i)
      end
    end
  end
  if ow then
    purge(ow.entities)
    purge(ow.npcs)
  end
  flight.riderEntity = nil
end

local function ensureRiderEntity(ow)
  if not (flight.active and ow and ow.player and flight.riderSprite
          and showRiderEnabled() and not isFirstPerson()) then
    removeRiderEntity(ow)
    return nil
  end

  local entity = flight.riderEntity
  if not entity then
    entity = {
      id = "sky_ride_rider",
      skyRideRider = true,
      passable = true,
      sprite = flight.riderSprite,
      pose = riderPose,
      draw = riderDraw,
    }
    flight.riderEntity = entity
  else
    entity.sprite = flight.riderSprite
  end
  syncRiderTransform(entity, ow.player)
  if not contains(ow.entities, entity) then table.insert(ow.entities, entity) end
  return entity
end


local function wrapPi(a)
  return (a + math.pi) % (2 * math.pi) - math.pi
end

local function approachAngle(now, target, rate, dt)
  local diff = wrapPi(target - now)
  local step = math.max(0, rate * (dt or 0))
  if math.abs(diff) <= step then return target end
  return now + (diff < 0 and -step or step)
end

local function installDramaticHooks()
  dramaticFirstPerson = dramaticFirstPerson or dramaticModule("FirstPerson")
  dramaticFreeMove = dramaticFreeMove or dramaticModule("FreeMove")

  if dramaticFirstPerson and not dramaticFirstPerson.dramaticSkyRideFrameHook then
    local innerFrame = dramaticFirstPerson.frame
    function dramaticFirstPerson.frame(me, cx, cy, vw, vh)
      if flight.active and isFirstPerson() and me then
        local cfg = RIDER_OFFSETS[flight.species] or DEFAULT_RIDER_OFFSET
