;(function()
-- Gold 1ST/3RD continuous Flight bridge.
--
-- Dramatic Shape / Dramaless FreeMove already owns camera-relative analog
-- movement on Gen 1 by wrapping OverworldState:handleInput. Gold does not run
-- that controller: Game2 polls its own World and quantises the pad to a single
-- held cardinal direction. While DSR Flight is cruising in 1ST/3RD, suppress
-- only that Gold held direction and drive the live Gen 2 player with the same
-- public FirstPerson moveVector()/moveWorld() pair instead.
--
-- The grid remains authoritative for logical cell identity and connections.
-- DSR's earlier Gen 2 flight bridge already owns terrain/entity bypass and
-- story/discovery-gated route seams.

local generation = mod.exports.runtimeGeneration or {}
local FREE_MOVE_EPS = 0.0001

local bridge = {
  world = nil,
  pollRaw = nil,
  pollNative = nil,
  pollWrapper = nil,
  posX = nil,
  posZ = nil,
  lastPx = nil,
  lastPy = nil,
}

local function isGold()
  return type(generation.isGen2) == "function"
    and generation.isGen2(Game) == true
end

local function liveWorld()
  return mod.exports._mountWorld(Game)
end

local function freeRoam(world)
  local check = mod.exports and mod.exports._mountFreeRoam
  if type(check) ~= "function" then return false end
  local ok, value = pcall(check, Game, world)
  return ok and value == true
end

local function freeFlightActive(world)
  return isGold()
    and flight.active and flight.phase == "cruise"
    and isFreeCamera()
    and world ~= nil and world.player ~= nil
    and freeRoam(world)
end

-- Provider FirstPerson:onTop() was written around Gen 1's stack shape. Gold
-- free roam deliberately has an empty stack, so teach the provider the same
-- generation-neutral free-roam predicate DSR already uses everywhere else.
local function installFirstPersonGoldTopBridge()
  if not (dramaticFirstPerson and type(dramaticFirstPerson.onTop) == "function") then
    return
  end
  if dramaticFirstPerson.dramaticSkyRideGen2TopBridge then return end
  local nativeOnTop = dramaticFirstPerson.onTop
  dramaticFirstPerson.onTop = function()
    if isGold() then return freeRoam(liveWorld()) end
    return nativeOnTop()
  end
  dramaticFirstPerson.dramaticSkyRideGen2TopBridge = true
end

local function resetPosition()
  bridge.posX, bridge.posZ = nil, nil
  bridge.lastPx, bridge.lastPy = nil, nil
  if dramaticFirstPerson and dramaticFirstPerson.releaseBody then
    pcall(dramaticFirstPerson.releaseBody)
  end
end

local function adoptPosition(player)
  bridge.posX = (tonumber(player.px) or player.cellX * 16) + 8
  bridge.posZ = (tonumber(player.py) or player.cellY * 16) + 8
  bridge.lastPx, bridge.lastPy = player.px, player.py
end

-- Gold's World:pollInput calls heldDirection(), which reduces even an analog
-- stick to up/down/left/right. Keep every other input path native and clear
-- only heldDir while our continuous solver owns airborne 1ST/3RD movement.
local function installPollBridge(world)
  if not (isGold() and world) then return end
  if bridge.world == world and rawget(world, "_dramaticSkyRideFreeFlightPoll")
     == bridge.pollWrapper then return end

  if bridge.world and bridge.pollWrapper
     and rawget(bridge.world, "pollInput") == bridge.pollWrapper then
    if bridge.pollRaw == nil then rawset(bridge.world, "pollInput", nil)
    else rawset(bridge.world, "pollInput", bridge.pollRaw) end
  end

  bridge.world = world
  bridge.pollRaw = rawget(world, "pollInput")
  bridge.pollNative = world.pollInput
  bridge.pollWrapper = function(self, input, ...)
    if freeFlightActive(self) then
      self.heldDir = nil
      local p = self.player
      if p and not p.moving then
        p.turnTimer = 0
        p.turnArmed = true
      end
      return nil
    end
    return bridge.pollNative(self, input, ...)
  end
  rawset(world, "pollInput", bridge.pollWrapper)
  rawset(world, "_dramaticSkyRideFreeFlightPoll", bridge.pollWrapper)
end

local function flightSpeedPerFrame()
  local base = dramaticFreeMove and tonumber(dramaticFreeMove.WALK) or 1.0
  local percent = tonumber(optionValue("flight_speed", 100)) or 100
  percent = math.max(50, math.min(200, percent))
  local multiplier = percent / 100
  if flightBoostEnabled() then
    multiplier = multiplier
      * (1 + (BOOST_MAX_MULTIPLIER - 1) * (tonumber(flight.boost) or 0))
  end
  return base * multiplier
end

local function connectionDirection(world, cx, cy)
  local map = world and world.map
  local p = world and world.player
  if not (map and p) then return nil end
  if map.inBounds and map:inBounds(cx, cy) then return nil end
  if cx < p.cellX then return "left" end
  if cx > p.cellX then return "right" end
  if cy < p.cellY then return "up" end
  if cy > p.cellY then return "down" end
  return nil
end

local function tryConnection(world, dir)
  if not (dir and world and type(world.tryConnection) == "function") then
    return false
  end
  local ok, crossed = pcall(world.tryConnection, world, dir)
  if ok and crossed then
    resetPosition()
    return true
  end
  return false
end

local function axisMoveAllowed(world, x, z)
  local map = world and world.map
  if not (map and map.inBounds) then return false end
  return map:inBounds(math.floor(x / 16), math.floor(z / 16))
end

local function applyContinuousFlight(world, dt)
  if not freeFlightActive(world) then
    resetPosition()
    return false
  end
  local p = world.player
  if p.moving or p.inputLocked then
    resetPosition()
    return false
  end
  if type(world.busy) == "function" then
    local okBusy, busy = pcall(world.busy, world)
    if okBusy and busy then
      resetPosition()
      return false
    end
  end
  if not (dramaticFirstPerson
      and type(dramaticFirstPerson.moveVector) == "function"
      and type(dramaticFirstPerson.moveWorld) == "function") then
    return false
  end

  if bridge.posX == nil or bridge.posZ == nil
     or math.abs((tonumber(p.px) or 0) - (tonumber(bridge.lastPx) or 0)) > FREE_MOVE_EPS
     or math.abs((tonumber(p.py) or 0) - (tonumber(bridge.lastPy) or 0)) > FREE_MOVE_EPS then
    adoptPosition(p)
  end

  local mx, mz = dramaticFirstPerson.moveVector()
  mx, mz = tonumber(mx) or 0, tonumber(mz) or 0
  if math.abs(mx) < FREE_MOVE_EPS and math.abs(mz) < FREE_MOVE_EPS then
    if dramaticFirstPerson.pointBody then
      local okFacing, facing = pcall(dramaticFirstPerson.pointBody, 0, 0)
      if okFacing and facing then p.facing = facing end
    end
    bridge.lastPx, bridge.lastPy = p.px, p.py
    return false
  end

  local wx, wz = dramaticFirstPerson.moveWorld(mx, mz)
  wx, wz = tonumber(wx) or 0, tonumber(wz) or 0
  local frameScale = math.max(0, math.min(3,
    (tonumber(dt) or (1 / 60)) * 60))
  local speed = flightSpeedPerFrame() * frameScale
  local dx, dz = wx * speed, wz * speed

  if dramaticFirstPerson.pointBody then
    local okFacing, facing = pcall(dramaticFirstPerson.pointBody, wx, wz)
    if okFacing and facing then p.facing = facing end
  elseif dx ~= 0 or dz ~= 0 then
    p.facing = facingFromYaw(math.atan2(dx, dz))
  end

  -- main_07's camera-follow gate compares stack:top() with the overworld,
  -- which is never true in Gold free roam. Reuse the same follow math here so
  -- 1ST/3RD behaves identically once Gold gains continuous movement.
  if cameraFollowEnabled() and (flight.cameraManualTimer or 0) <= 0
     and (mz or 0) > -0.25 and (wx ~= 0 or wz ~= 0) then
    local targetYaw = math.atan2(wx, wz)
    local rate = isThirdPerson() and CAMERA_FOLLOW_RATE_3RD
                 or CAMERA_FOLLOW_RATE_1ST
    dramaticFirstPerson.yaw = wrapPi(approachAngle(
      tonumber(dramaticFirstPerson.yaw) or targetYaw,
      targetYaw, rate, tonumber(dt) or (1 / 60)))
  end

  -- Axis-separated bounds handling keeps diagonal edge movement smooth. In
  -- Flight, DSR's existing Gen 2 collision bridge already opens tile/entity
  -- refusals; only map bounds and authored connections remain here.
  local nextX = bridge.posX + dx
  if axisMoveAllowed(world, nextX, bridge.posZ) then
    bridge.posX = nextX
  elseif math.abs(dx) > FREE_MOVE_EPS then
    local dir = connectionDirection(world,
      math.floor(nextX / 16), math.floor(bridge.posZ / 16))
    if tryConnection(world, dir) then return true end
  end

  local nextZ = bridge.posZ + dz
  if axisMoveAllowed(world, bridge.posX, nextZ) then
    bridge.posZ = nextZ
  elseif math.abs(dz) > FREE_MOVE_EPS then
    local dir = connectionDirection(world,
      math.floor(bridge.posX / 16), math.floor(nextZ / 16))
    if tryConnection(world, dir) then return true end
  end

  p.px, p.py = bridge.posX - 8, bridge.posZ - 8
  p.cellX, p.cellY = math.floor(bridge.posX / 16), math.floor(bridge.posZ / 16)
  p.targetX, p.targetY = nil, nil
  p.moving, p.progress = false, 0
  bridge.lastPx, bridge.lastPy = p.px, p.py
  return math.abs(dx) > FREE_MOVE_EPS or math.abs(dz) > FREE_MOVE_EPS
end

installFirstPersonGoldTopBridge()

-- Gold calls Gen1Facade.worldTick() at the end of World:step, which reaches
-- this compatibility OverworldState:update chain. Install the poll gate for
-- the next logic tick, let older DSR bridges settle, then apply the continuous
-- position for this tick.
local previousUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  installFirstPersonGoldTopBridge()
  if isGold() and Game.overworld == self then installPollBridge(self) end
  local result = previousUpdate(self, dt, ...)
  if isGold() and Game.overworld == self then
    applyContinuousFlight(self, dt)
  else
    resetPosition()
  end
  return result
end

mod.exports.gen2FreeFlight = {
  active = function() return freeFlightActive(liveWorld()) end,
  continuousPosition = function() return bridge.posX, bridge.posZ end,
  pollInstalled = function() return bridge.pollWrapper ~= nil end,
}

log("Gold 1ST/3RD continuous Flight bridge loaded")
end)();