;(function()
-- Gold does not instantiate src.world.Player. Its live actor is a
-- src.world.gen2.Player, so the Gen 1 Player:pose / Player:draw wrappers above
-- cannot own either its sprite or its collision path. Keep this bridge on the
-- live instances exposed by Game2 instead of importing and monkey-patching a
-- private Gen 2 class.

local generation = mod.exports.runtimeGeneration or {}
local visual = {
  player = nil,
  originalSprite = nil,
  originalSpriteDef = nil,
  originalYOffset = nil,
  originalDrawRaw = nil,
  nativeDraw = nil,
  drawWrapper = nil,
  installedSprite = nil,
  kind = nil,
  riderProxy = { id = "dsr_gen2_rider_proxy", passable = true },
}
local guardedWorld = nil
local guardState = nil
local gen2Map = nil
local fixedStep = nil
local CONNECTION_KEY = {
  up = "north", down = "south", left = "west", right = "east",
}

local function isGold()
  return type(generation.isGen2) == "function"
    and generation.isGen2(Game) == true
end

local function liveWorld()
  return mod.exports._mountWorld(Game)
end

local function gen2ConnectionModules()
  if not gen2Map then
    local ok, value = pcall(require, "src.world.gen2.Map")
    if ok then gen2Map = value end
  end
  if not fixedStep then
    local ok, value = pcall(require, "src.core.FixedStep")
    if ok then fixedStep = value end
  end
  return gen2Map, fixedStep
end

local function desiredVisual()
  if flight.active and flight.sprite then return flight.sprite, "flight" end
  if ground and ground.active and ground.sprite then
    return ground.sprite, "ground"
  end
  local waterVisual = mod.exports and mod.exports._waterRideVisual or nil
  if type(waterVisual) == "function" then
    local ok, sprite = pcall(waterVisual)
    if ok and sprite then return sprite, "water" end
  end
  return nil, nil
end

local function restorePlayerVisual()
  local player = visual.player
  if player then
    -- Do not overwrite a sprite another runtime deliberately installed after
    -- our last tick. The ordinary case still restores the exact native Gold
    -- renderer (normal / bike / surf) captured beneath the mount.
    if player.sprite == visual.installedSprite then
      player.sprite = visual.originalSprite
      player.spriteDef = visual.originalSpriteDef
    end
    player.spriteYOffset = visual.originalYOffset
    if rawget(player, "draw") == visual.drawWrapper then
      rawset(player, "draw", visual.originalDrawRaw)
    end
  end
  visual.player = nil
  visual.originalSprite = nil
  visual.originalSpriteDef = nil
  visual.originalYOffset = nil
  visual.originalDrawRaw = nil
  visual.nativeDraw = nil
  visual.drawWrapper = nil
  visual.installedSprite = nil
  visual.kind = nil
end

local function flightLift(world, player)
  if not (flight.active and world and world.map and player) then return 0 end
  local floor = terrainGroundHeight(world.map, player.cellX, player.cellY)
  return math.max(0, (tonumber(flight.altitude) or 0) - floor)
end

local function mountedRiderPose(kind)
  local proxy = visual.riderProxy
  if kind == "flight" then
    if not (showRiderEnabled() and flight.riderSprite) or isFirstPerson() then
      return nil
    end
    proxy.sprite = flight.riderSprite
    return riderPose(proxy)
  end
  if kind == "ground" then
    if not (ground and ground.riderSprite) or isFirstPerson() then return nil end
    proxy.sprite = ground.riderSprite
    return groundRiderPose(proxy)
  end
  if kind == "water" then
    if isFirstPerson() then return nil end
    local waterPose = mod.exports and mod.exports._waterRideRiderPose or nil
    if type(waterPose) ~= "function" then return nil end
    local ok, sprite, px, py, facing, phase, flip, hopping =
      pcall(waterPose, proxy)
    if not ok then return nil end
    return sprite, px, py, facing, phase, flip, hopping
  end
  return nil
end

local function drawMountedPlayer(player, ox, oy, scale)
  local mount = visual.installedSprite
  if not (mount and mount.draw) then
    return visual.nativeDraw(player, ox, oy, scale)
  end

  local G = love.graphics
  scale = tonumber(scale) or 1
  G.push()
  G.translate(tonumber(ox) or 0, tonumber(oy) or 0)
  G.scale(scale, scale)
  G.setColor(1, 1, 1, 1)

  -- Gold only Y-sorts/draws its `npcs` list, while DSR's compatibility rider
  -- is intentionally a passable `entities` entry. Compose the crop directly
  -- with the live player so it cannot vanish or render one tile beside the
  -- Pokemon under Gold's different draw signature.
  local rider, rx, ry, rfacing, rphase, rflip = mountedRiderPose(visual.kind)
  if rider and rider.draw then
    rider:draw(rx, ry, 0, 0, rfacing, rphase, rflip)
  end

  local phase
  if visual.kind == "flight" then
    phase = (tonumber(flight.anim) or 0) >= 16 and 1 or 0
  elseif type(player.walkPhase) == "function" then
    phase = player:walkPhase()
  else
    phase = 0
  end
  mount:draw(player.px, player.py + (player.spriteYOffset or 0), 0, 0,
    player.facing, phase, player.stepFlip)
  G.pop()
end

local function installMountedDraw(player)
  visual.originalDrawRaw = rawget(player, "draw")
  visual.nativeDraw = player.draw
  visual.drawWrapper = function(self, ox, oy, scale)
    if visual.player == self and self.sprite == visual.installedSprite then
      return drawMountedPlayer(self, ox, oy, scale)
    end
    return visual.nativeDraw(self, ox, oy, scale)
  end
  rawset(player, "draw", visual.drawWrapper)
end

local function reconcilePlayerVisual(world)
  if not (isGold() and world and world.player) then
    restorePlayerVisual()
    return
  end

  local player = world.player
  local sprite, kind = desiredVisual()
  if not sprite then
    restorePlayerVisual()
    return
  end

  if visual.player ~= player then
    restorePlayerVisual()
    visual.player = player
    visual.originalSprite = player.sprite
    visual.originalSpriteDef = player.spriteDef
    visual.originalYOffset = player.spriteYOffset
    installMountedDraw(player)
  elseif player.sprite ~= visual.installedSprite then
    -- Gold may legitimately change its underlying player state while a mount
    -- stays active (notably Suicune at a shoreline). Remember that new native
    -- sprite so dismounting restores the correct state rather than the one
    -- that happened to exist at take-off.
    visual.originalSprite = player.sprite
    visual.originalSpriteDef = player.spriteDef
  end

  visual.installedSprite = sprite
  visual.kind = kind
  if kind == "flight" then
    flight.anim = ((tonumber(flight.anim) or 0) + 1) % 32
  end
  player.sprite = sprite
  player.spriteDef = sprite.def or visual.originalSpriteDef

  if kind == "flight" then
    player.spriteYOffset = -math.floor(flightLift(world, player) + 0.5)
  else
    player.spriteYOffset = 0
  end
end

local function suppressFlightTerrainFx(world)
  local player = world and world.player or nil
  if not (flight.active and player) then return end

  -- Gold arms ShakeGrass at the beginning of every ordinary grid step. Flight
  -- deliberately reuses that native step path for movement, but the airborne
  -- mount must not disturb vegetation underneath it. Clear only the transient
  -- visual marker after the engine tick; encounters, collision and the native
  -- inGrass state used again after landing remain untouched.
  player.grassShake = nil
end

local function restoreFlightGuards()
  local world, state = guardedWorld, guardState
  if world and state then
    for name, raw in pairs(state.rawMethods) do
      if raw == state.absent then
        rawset(world, name, nil)
      else
        rawset(world, name, raw)
      end
    end
    if rawget(world, "_dramaticSkyRideGen2Bridge") == state then
      rawset(world, "_dramaticSkyRideGen2Bridge", nil)
    end
  end
  guardedWorld, guardState = nil, nil
end

local function connectionInfo(world, dir)
  local Map2 = gen2ConnectionModules()
  if not (Map2 and world and world.map and world.player
          and world.maps and CONNECTION_KEY[dir]) then return nil end
  local conn = world.map:connection(CONNECTION_KEY[dir])
  local target = conn and (conn.mapId
    or (type(conn.map) == "string" and conn.map)) or nil
  local dest = target and world.maps[target] or nil
  if not (conn and target and dest) then return nil end
  local x, y = Map2.connectionLanding(dest, conn, dir,
    world.player.cellX, world.player.cellY)
  local delta = Map2.DELTA and Map2.DELTA[dir] or nil
  if not (x and y and delta) then return nil end
  return {
    conn = conn, target = target, dest = dest,
    x = x, y = y, delta = delta,
  }
end

local function blockedConnectionNotice(label)
  if (flight.storyGateNoticeCooldown or 0) <= 0 then
    notifyHud(label)
    feedback("blocked")
    flight.storyGateNoticeCooldown = 1.0
  end
end

local function flightConnectionAllowed(target)
  local rules = mod.exports and mod.exports.flightRules or nil
  if not rules then return true end
  if type(rules.storyGateBlocks) == "function" then
    local ok, blocked = pcall(rules.storyGateBlocks, target)
    if ok and blocked then
      blockedConnectionNotice("STORY BLOCKED")
      return false
    end
  end
  if type(rules.discoveryGates) == "function"
     and type(rules.isMapReached) == "function" then
    local okEnabled, enabled = pcall(rules.discoveryGates)
    local okReached, reached = pcall(rules.isMapReached, target)
    if okEnabled and enabled == true and okReached and reached == false then
      blockedConnectionNotice("AREA NOT VISITED")
      return false
    end
  end
  return true
end

local function installFlightGuards(world)
  if not (isGold() and world) then return end
  if guardedWorld == world and guardState then return end
  restoreFlightGuards()

  -- A previous hot-loaded copy can leave its reversible instance layer in
  -- place. Ask it to unwind before this copy captures the native methods.
  local previous = rawget(world, "_dramaticSkyRideGen2Bridge")
  if previous and type(previous.restore) == "function" then
    pcall(previous.restore)
  end

  local absent = {}
  local state = { rawMethods = {}, absent = absent }
  guardedWorld, guardState = world, state

  local function rawMethod(name)
    local raw = rawget(world, name)
    state.rawMethods[name] = raw == nil and absent or raw
    return world[name]
  end

  -- Game2 sends A straight to World:interact; it never calls the Gen 1
  -- OverworldState:handleInput seam where normal DSR landing is handled.
  local interact = rawMethod("interact")
  rawset(world, "interact", function(self, ...)
    if flight.active then
      if flight.phase == "cruise" then beginLanding(Game, false) end
      return true
    end
    return interact(self, ...)
  end)

  -- Gold normally refuses a seamless connection when the destination edge
  -- is not walkable on foot. Flight still honours authored connections and
  -- map/story gates, but may finish that same native seam in open air.
  local tryConnection = rawMethod("tryConnection")
  if type(tryConnection) == "function" then
    rawset(world, "tryConnection", function(self, dir, ...)
      if not flight.active then return tryConnection(self, dir, ...) end
      local info = connectionInfo(self, dir)
      if not info then return tryConnection(self, dir, ...) end
      if not flightConnectionAllowed(info.target) then return false end

      local crossed = tryConnection(self, dir, ...)
      if crossed then return crossed end

      local p = self.player
      local loaded = self:setMap(info.target, info.x, info.y, dir,
        { seamless = true })
      if not loaded then return false end
      p.cellX, p.cellY = info.x - info.delta[1], info.y - info.delta[2]
      p.px, p.py = p.cellX * 16, p.cellY * 16
      p.facing = dir
      p.targetX, p.targetY = info.x, info.y
      p.moving, p.progress = true, 0
      p.inGrass, p.grassShake = false, nil
      local _, FixedStep = gen2ConnectionModules()
      if FixedStep and type(FixedStep.discardCatchup) == "function" then
        FixedStep:discardCatchup()
      end
      return true
    end)
  end

  -- These are the Gold equivalents of the consequences suppressed by DSR's
  -- Gen 1 onStepComplete/checkTrainerSight wrappers. Route-edge connections
  -- remain native; only per-cell ground events are ignored while airborne.
  for _, name in ipairs({
    "checkTrainerBattle", "checkWarpOnArrive", "tryCoordScript",
    "countStep", "tryWildEncounter", "checkCarpetWhileStanding",
  }) do
    local native = rawMethod(name)
    if type(native) == "function" then
      rawset(world, name, function(self, ...)
        if flight.active then return false end
        return native(self, ...)
      end)
    end
  end

  state.restore = function()
    if guardedWorld == world and guardState == state then
      restoreFlightGuards()
    end
  end
  rawset(world, "_dramaticSkyRideGen2Bridge", state)
end

-- Gold's real Player invokes this shared hook. Open only tile/entity refusals
-- while cruising in the air. Bounds stay refused so World:tryConnection owns
-- route seams, and downstream mods still receive the promoted verdict.
mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
  if not (isGold() and flight.active and ctx and ctx.mover) then
    return next(allowed, ctx)
  end
  local world = liveWorld()
  if not (world and world.player == ctx.mover) then return next(allowed, ctx) end
  if allowed == false and ctx.reason ~= "bounds" then
    ctx.reason = "dramatic_flight"
    return next(true, ctx)
  end
  return next(allowed, ctx)
end, 120)

-- Outermost Gold tick: the engine and every earlier compatibility layer first
-- get a chance to alter player state, then the mount becomes the actual sprite
-- that Gold will draw on this frame.
local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousUpdate(self, dt, ...)
  if isGold() and Game.overworld == self then
    if flight.active then installFlightGuards(self) else restoreFlightGuards() end
    suppressFlightTerrainFx(self)
    reconcilePlayerVisual(self)
  else
    restoreFlightGuards()
    restorePlayerVisual()
  end
  return result
end

mod.exports.gen2PlayerBridge = {
  active = function() return isGold() and visual.player ~= nil end,
  visualKind = function() return visual.kind end,
  ownsPlayerSprite = function()
    return visual.player ~= nil
      and visual.player.sprite == visual.installedSprite
  end,
  flightGuardsActive = function()
    return guardedWorld ~= nil and guardState ~= nil
  end,
  nativePlayerSprite = function(player)
    if player and visual.player == player then
      -- applyPlayerState("normal") runs synchronously when Flight starts from
      -- Surf, before the bridge receives its next update.  Keep the native
      -- source in step immediately so buildRiderSprite never crops Gold's
      -- obsolete SPRITE_SURF sheet onto the flying mount.
      if player.sprite and player.sprite ~= visual.installedSprite then
        visual.originalSprite = player.sprite
        visual.originalSpriteDef = player.spriteDef
      end
      if visual.originalSprite then
        return visual.originalSprite, visual.originalSpriteDef
      end
    end
    return player and player.sprite or nil,
      player and player.spriteDef or nil
  end,
  riderPlayerSprite = function(player)
    local sprite, def
    if player and visual.player == player then
      if player.sprite and player.sprite ~= visual.installedSprite then
        visual.originalSprite = player.sprite
        visual.originalSpriteDef = player.spriteDef
      end
      sprite, def = visual.originalSprite, visual.originalSpriteDef
    else
      sprite, def = player and player.sprite or nil,
        player and player.spriteDef or nil
    end

    -- Gold's native Surf sheets already contain the generic water vehicle.
    -- They are correct for traversal/restoration but can never be cropped as
    -- the human rider placed on Gyarados or Suicune. Build a palette-correct
    -- temporary SPRITE_CHRIS renderer solely as the rider-sheet source.
    local id = def and tostring(def.id or "") or ""
    if isGold() and (id == "SPRITE_SURF" or id == "SPRITE_SURFING_PIKACHU") then
      local world = liveWorld()
      local normalDef = world and world.sprites and world.sprites.SPRITE_CHRIS
      if normalDef then
        local proxy = {
          spriteDef = normalDef,
          sprite = SpriteRenderer.new(normalDef, "dsr_gen2_rider_source"),
        }
        if type(world.applySpritePalette) == "function" then
          pcall(world.applySpritePalette, world, proxy)
        end
        return proxy.sprite, normalDef
      end
    end
    return sprite, def
  end,
  riderSpriteId = function()
    local sprite
    if visual.kind == "flight" then
      sprite = flight and flight.riderSprite or nil
    elseif visual.kind == "ground" then
      sprite = ground and ground.riderSprite or nil
    elseif visual.kind == "water" then
      local pose = mod.exports and mod.exports._waterRideRiderPose or nil
      if type(pose) == "function" then
        local ok, value = pcall(pose, visual.riderProxy)
        if ok then sprite = value end
      end
    end
    return sprite and sprite.def and sprite.def.id or nil
  end,
}

log("Gold live-player render, landing and open-air movement/connection bridge loaded")
end)();
