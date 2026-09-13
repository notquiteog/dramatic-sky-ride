(function()
-- -------------------------------------------------------------------------
-- Stadium 2 mount motion layer.
--
-- Stadium 2 supplies battle skeletons, not an overworld locomotion library:
-- there are no canonical walk/run/fly/swim clips shared by all species.
-- DSR therefore keeps each species' genuine Stadium idle skeleton and adapts
-- PRESENTATION to the mount mechanic: playback cadence, body lean, banking,
-- climb/dive pitch and restrained role-specific bob.  This is deliberately
-- conservative: no guessed bone indices and no fabricated generic gait that
-- could tear a species-specific N64 rig apart.
--
-- Coverage is explicit for every DSR 0.1.7 mount role that is realistic with
-- the Stadium 2 cache: 16 Flight, 17 Ground Ride and 8 Visible Surf entries.
-- Lugia appears in both Flight and Surf; Suicune dynamically uses its water
-- posture while the amphibious Ground Ride is on water.
-- -------------------------------------------------------------------------

local DEG = math.pi / 180
local MIN_SAMPLE_DT = 1 / 240
local MAX_SAMPLE_DT = 0.12
local MOVE_EPS = 2.5
local warned = {}
local statsByDex = {}

local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
end

local function clamp(v, lo, hi)
  v = tonumber(v) or 0
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function lerp(a, b, t)
  return a + (b - a) * clamp(t, 0, 1)
end

local function nowSeconds()
  if love and love.timer and type(love.timer.getTime) == "function" then
    local ok, value = pcall(love.timer.getTime)
    value = ok and tonumber(value) or nil
    if value then return value end
  end
  return nil
end

local function findUpvalue(fn, wanted)
  if type(fn) ~= "function" or not (debug and debug.getupvalue) then return nil end
  for index = 1, 160 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return index, value end
  end
  return nil
end

local function setUpvalue(fn, index, value)
  if not (type(fn) == "function" and index and debug and debug.setupvalue) then
    return false
  end
  return pcall(debug.setupvalue, fn, index, value)
end

-- Role defaults are intentionally mild.  Per-species rows tune amplitude,
-- not semantics: every model keeps its own authentic Stadium skeleton.
local DEFAULT = {
  flight = { speedRef=78, idleRate=.90, moveRate=1.08, boostRate=.14,
    bob=.34, bobIdle=.12, freq=1.55, pitch=4.5, climb=6.0, bank=8.0 },
  ground = { speedRef=62, idleRate=.88, moveRate=1.12, gallopRate=.14,
    bob=.30, bobIdle=0, freq=1.90, pitch=2.2, climb=0, bank=1.2 },
  water = { speedRef=54, idleRate=.90, moveRate=1.06, boostRate=0,
    bob=.46, bobIdle=.30, freq=1.10, pitch=2.4, climb=0, bank=4.0 },
}

local function p(role, family, values)
  local out = { role=role, family=family }
  for k, v in pairs(DEFAULT[role]) do out[k] = v end
  for k, v in pairs(values or {}) do out[k] = v end
  return out
end

-- Every currently supported Flight mount.
local FLIGHT = {
  CHARIZARD = p("flight", "winged_dragon", { bob=.38, pitch=5.5, climb=7.0, bank=10.0, moveRate=1.12 }),
  PIDGEOT = p("flight", "bird", { bob=.42, freq=1.80, bank=11.0, moveRate=1.14 }),
  FEAROW = p("flight", "bird", { bob=.40, freq=1.90, bank=11.5, moveRate=1.15 }),
  GOLBAT = p("flight", "bat", { bob=.50, freq=2.00, bank=12.0, pitch=4.0, moveRate=1.16 }),
  AERODACTYL = p("flight", "pterosaur", { bob=.30, freq=1.35, pitch=5.5, bank=10.0 }),
  ARTICUNO = p("flight", "large_bird", { bob=.34, freq=1.35, bank=9.0, moveRate=1.08 }),
  ZAPDOS = p("flight", "large_bird", { bob=.36, freq=1.55, bank=9.5, moveRate=1.10 }),
  MOLTRES = p("flight", "large_bird", { bob=.38, freq=1.45, bank=9.0, moveRate=1.09 }),
  DRAGONAIR = p("flight", "serpentine", { bob=.52, bobIdle=.22, freq=.90, pitch=3.0, climb=4.5, bank=4.0, moveRate=1.04 }),
  DRAGONITE = p("flight", "winged_dragon", { bob=.34, freq=1.45, pitch=5.0, climb=6.5, bank=9.0, moveRate=1.10 }),
  NOCTOWL = p("flight", "bird", { bob=.38, freq=1.55, bank=10.0, moveRate=1.10 }),
  CROBAT = p("flight", "bat", { bob=.48, freq=2.05, bank=12.5, pitch=4.0, moveRate=1.17 }),
  XATU = p("flight", "levitating_bird", { bob=.28, bobIdle=.18, freq=1.15, pitch=3.2, climb=4.5, bank=6.0, moveRate=1.05 }),
  SKARMORY = p("flight", "armored_bird", { bob=.28, freq=1.25, pitch=4.5, climb=5.5, bank=8.0, moveRate=1.07 }),
  LUGIA = p("flight", "large_winged", { bob=.30, freq=1.05, pitch=5.0, climb=6.0, bank=8.0, moveRate=1.06 }),
  HO_OH = p("flight", "large_bird", { bob=.34, freq=1.20, pitch=4.8, climb=5.8, bank=8.5, moveRate=1.07 }),
}

-- Every currently supported Ground Ride mount.  Because Stadium does not
-- provide locomotion clips, the heavy/biped profiles intentionally use very
-- small body motion instead of pretending an attack/reaction is a walk cycle.
local GROUND = {
  ARCANINE = p("ground", "fast_quadruped", { speedRef=72, bob=.38, freq=2.25, pitch=3.2, bank=1.8, moveRate=1.16 }),
  RAPIDASH = p("ground", "equine", { speedRef=76, bob=.44, freq=2.45, pitch=3.4, bank=1.8, moveRate=1.18, gallopRate=.18 }),
  DODRIO = p("ground", "runner_bird", { speedRef=72, bob=.46, freq=2.55, pitch=2.6, bank=2.2, moveRate=1.18 }),
  RHYHORN = p("ground", "heavy_quadruped", { speedRef=54, bob=.25, freq=1.55, pitch=1.8, moveRate=1.06, gallopRate=.10 }),
  RHYDON = p("ground", "heavy_biped", { speedRef=52, bob=.20, freq=1.40, pitch=1.5, bank=.8, moveRate=1.04, gallopRate=.08 }),
  KANGASKHAN = p("ground", "large_biped", { speedRef=56, bob=.24, freq=1.55, pitch=1.8, bank=.9, moveRate=1.07 }),
  TAUROS = p("ground", "bovine", { speedRef=74, bob=.40, freq=2.35, pitch=3.0, bank=1.8, moveRate=1.17, gallopRate=.18 }),
  SNORLAX = p("ground", "very_heavy_biped", { speedRef=44, bob=.12, freq=1.05, pitch=.8, bank=.4, moveRate=.98, gallopRate=.04 }),
  MEGANIUM = p("ground", "heavy_quadruped", { speedRef=58, bob=.26, freq=1.65, pitch=1.8, moveRate=1.07 }),
  GIRAFARIG = p("ground", "equine", { speedRef=70, bob=.38, freq=2.15, pitch=2.8, bank=1.5, moveRate=1.14 }),
  URSARING = p("ground", "heavy_biped", { speedRef=52, bob=.20, freq=1.35, pitch=1.3, bank=.7, moveRate=1.04 }),
  DONPHAN = p("ground", "heavy_quadruped", { speedRef=58, bob=.26, freq=1.65, pitch=1.6, bank=1.0, moveRate=1.07 }),
  STANTLER = p("ground", "deer", { speedRef=74, bob=.40, freq=2.30, pitch=3.0, bank=1.7, moveRate=1.16, gallopRate=.16 }),
  RAIKOU = p("ground", "fast_quadruped", { speedRef=80, bob=.38, freq=2.40, pitch=3.4, bank=2.0, moveRate=1.18, gallopRate=.18 }),
  ENTEI = p("ground", "large_quadruped", { speedRef=72, bob=.34, freq=2.10, pitch=2.8, bank=1.6, moveRate=1.13, gallopRate=.15 }),
  SUICUNE = p("ground", "fast_quadruped", { speedRef=80, bob=.36, freq=2.35, pitch=3.2, bank=2.0, moveRate=1.17, gallopRate=.18 }),
  TYRANITAR = p("ground", "very_heavy_biped", { speedRef=48, bob=.16, freq=1.15, pitch=1.0, bank=.5, moveRate=1.00, gallopRate=.05 }),
}

-- Every currently supported Visible Surf mount.
local WATER = {
  BLASTOISE = p("water", "bulky_swimmer", { bob=.38, bobIdle=.24, freq=.95, pitch=1.8, bank=3.0 }),
  TENTACRUEL = p("water", "tentacled", { bob=.56, bobIdle=.38, freq=1.15, pitch=1.5, bank=4.0, moveRate=1.08 }),
  GYARADOS = p("water", "serpentine", { bob=.52, bobIdle=.30, freq=.85, pitch=2.8, bank=5.0, moveRate=1.09 }),
  LAPRAS = p("water", "large_swimmer", { bob=.42, bobIdle=.30, freq=.90, pitch=1.8, bank=3.2, moveRate=1.04 }),
  FERALIGATR = p("water", "bulky_swimmer", { bob=.40, bobIdle=.26, freq=1.00, pitch=2.0, bank=3.2, moveRate=1.06 }),
  MANTINE = p("water", "ray", { bob=.48, bobIdle=.30, freq=.82, pitch=3.0, bank=6.0, moveRate=1.08 }),
  KINGDRA = p("water", "serpentine", { bob=.46, bobIdle=.30, freq=.90, pitch=2.4, bank=4.5, moveRate=1.07 }),
  LUGIA = p("water", "large_swimmer", { bob=.46, bobIdle=.32, freq=.82, pitch=2.8, bank=4.5, moveRate=1.05 }),
}

local DEX = {
  CHARIZARD=6, PIDGEOT=18, FEAROW=22, GOLBAT=42, ARCANINE=59,
  BLASTOISE=9, TENTACRUEL=73, RAPIDASH=78, DODRIO=85, RHYHORN=111,
  RHYDON=112, KANGASKHAN=115, TAUROS=128, SNORLAX=143, GYARADOS=130,
  LAPRAS=131, AERODACTYL=142, ARTICUNO=144, ZAPDOS=145, MOLTRES=146,
  DRAGONAIR=148, DRAGONITE=149, MEGANIUM=154, FERALIGATR=160,
  NOCTOWL=164, CROBAT=169, XATU=178, GIRAFARIG=203, URSARING=217,
  MANTINE=226, SKARMORY=227, KINGDRA=230, DONPHAN=232, STANTLER=234,
  RAIKOU=243, ENTEI=244, SUICUNE=245, TYRANITAR=248, LUGIA=249,
  HO_OH=250,
}

local BY_DEX = { flight={}, ground={}, water={} }
for species, profile in pairs(FLIGHT) do BY_DEX.flight[DEX[species]] = profile end
for species, profile in pairs(GROUND) do BY_DEX.ground[DEX[species]] = profile end
for species, profile in pairs(WATER) do BY_DEX.water[DEX[species]] = profile end

local function waterRideSpecies()
  local ex = mod.exports or {}
  if type(ex.isWaterRiding) ~= "function" or type(ex.waterMountSpecies) ~= "function" then
    return nil
  end
  local okActive, active = pcall(ex.isWaterRiding)
  if not (okActive and active == true) then return nil end
  local okSpecies, species = pcall(ex.waterMountSpecies)
  return okSpecies and species or nil
end

local function roleFor(runtime)
  local species = runtime and runtime.species
  if flight and flight.active and flight.species == species then return "flight", species end
  if ground and ground.active and ground.species == species then
    -- Suicune remains Ground Ride's lifecycle owner on water, but presentation
    -- should use the calmer water profile while its amphibious flag is armed.
    if species == "SUICUNE" and ground.amphibiousWater == true then
      return "water", species
    end
    return "ground", species
  end
  local water = waterRideSpecies()
  if water and (not species or water == species) then return "water", water end
  return nil, species
end

local function profileFor(role, species, dex)
  local set = role == "flight" and FLIGHT or role == "ground" and GROUND or WATER
  return set[species] or (BY_DEX[role] and BY_DEX[role][tonumber(dex)]) or nil
end

local FACING = { up=0, right=1, down=2, left=3 }
local function turnSign(oldFacing, newFacing)
  local a, b = FACING[oldFacing], FACING[newFacing]
  if a == nil or b == nil or a == b then return 0 end
  local d = (b - a) % 4
  if d == 1 then return 1 end
  if d == 3 then return -1 end
  return 0
end

local function worldPosition(role)
  local ow = Game and Game.overworld or nil
  local player = ow and ow.player or nil
  if not player then return nil end
  local y
  if role == "flight" then
    y = tonumber(flight and flight.altitude) or 0
  else
    y = 0
    if ow.map and type(terrainGroundHeight) == "function" then
      local ok, value = pcall(terrainGroundHeight, ow.map, player.cellX, player.cellY)
      if ok and tonumber(value) then y = tonumber(value) end
    end
  end
  return tonumber(player.px) or 0, y, tonumber(player.py) or 0, player.facing or "down"
end

local function sampleMotion(runtime, role, profile)
  runtime._dsrMountMotion = runtime._dsrMountMotion or {
    speed=0, vertical=0, turn=0, clock=0, intensity=0, rate=1,
  }
  local s = runtime._dsrMountMotion
  local now = nowSeconds()
  local x, y, z, facing = worldPosition(role)
  if not (now and x) then return s end

  if s.wall and s.x then
    local dt = now - s.wall
    if dt >= MIN_SAMPLE_DT and dt <= MAX_SAMPLE_DT then
      local dx, dy, dz = x - s.x, y - s.y, z - s.z
      local speed = math.sqrt(dx*dx + dz*dz) / dt
      local vertical = dy / dt
      local a = 1 - 0.5 ^ (dt / 0.08)
      s.speed = s.speed + (speed - s.speed) * a
      s.vertical = s.vertical + (vertical - s.vertical) * a
      s.clock = s.clock + dt
      local sign = turnSign(s.facing, facing)
      if sign ~= 0 then s.turn = sign
      else s.turn = s.turn * (0.5 ^ (dt / 0.16)) end
      s.x, s.y, s.z, s.wall, s.facing = x, y, z, now, facing
    elseif dt > MAX_SAMPLE_DT then
      s.x, s.y, s.z, s.wall, s.facing = x, y, z, now, facing
      s.speed, s.vertical, s.turn = 0, 0, 0
    end
  else
    s.x, s.y, s.z, s.wall, s.facing = x, y, z, now, facing
  end

  local intensity = clamp((s.speed - MOVE_EPS) / math.max(1, profile.speedRef - MOVE_EPS), 0, 1)
  local boost = 0
  if role == "flight" then boost = clamp(flight and flight.boost or 0, 0, 1) end
  local gallop = 0
  if role == "ground" and ground then
    gallop = clamp(ground.speedBlend or (ground.gallop and 1 or 0), 0, 1)
  end
  s.intensity, s.boost, s.gallop = intensity, boost, gallop

  local extra = role == "ground" and profile.gallopRate * gallop
    or profile.boostRate * boost
  s.rate = clamp(lerp(profile.idleRate, profile.moveRate, intensity) + extra, .72, 1.38)

  local phase = s.clock * (profile.freq * (0.78 + intensity * 0.42)) * math.pi * 2
  local bobAmp = profile.bobIdle + profile.bob * intensity
  s.bob = math.sin(phase) * bobAmp

  if role == "flight" then
    local vnorm = clamp(s.vertical / 70, -1, 1)
    s.pitch = (profile.pitch * intensity + profile.pitch * .35 * boost - profile.climb * vnorm) * DEG
    s.roll = profile.bank * s.turn * math.max(.25, intensity) * DEG
  elseif role == "water" then
    s.pitch = (profile.pitch * intensity + math.sin(phase * .5) * .45) * DEG
    s.roll = (profile.bank * s.turn * math.max(.30, intensity)
      + math.sin(phase * .42) * .55) * DEG
  else
    s.pitch = profile.pitch * intensity * DEG
    s.roll = profile.bank * s.turn * math.max(.20, intensity) * DEG
  end

  statsByDex[runtime.dex or 0] = {
    dex=runtime.dex, species=runtime.species, role=role, family=profile.family,
    speed=s.speed, intensity=s.intensity, rate=s.rate, bob=s.bob,
    pitch=s.pitch / DEG, roll=s.roll / DEG, boost=boost, gallop=gallop,
  }
  return s
end

-- -------------------------------------------------------------------------
-- Skeleton playback cadence: decorate alpha.7's authoritative render clock.
-- The clock is nudged by (rate-1)*dt BEFORE the raw driver adds its own dt,
-- so the final Stadium sample advances at exactly rate*dt and never double
-- counts the Overworld update clock.
-- -------------------------------------------------------------------------
local playerPose = Player and Player.pose or nil
local advanceIndex, rawAdvance = findUpvalue(playerPose, "advance")
local maxWallIndex, maxWallDt = findUpvalue(rawAdvance, "MAX_WALL_DT")
maxWallDt = tonumber(maxWallDt) or MAX_SAMPLE_DT

local clockPatched = false
if type(rawAdvance) == "function" and advanceIndex then
  local function motionAdvance(runtime, provider)
    local role, species = roleFor(runtime)
    local profile = role and profileFor(role, species, runtime and runtime.dex) or nil
    if profile and runtime then
      local s = sampleMotion(runtime, role, profile)
      local now = nowSeconds()
      local last = tonumber(runtime._dsrRenderClockNow)
      if now and last then
        local dt = clamp(now - last, 0, maxWallDt)
        if dt > 0 then
          local base = math.max(0, tonumber(runtime._dsrRenderClockTime)
            or tonumber(runtime.time) or 0)
          runtime._dsrRenderClockTime = math.max(0, base + (s.rate - 1) * dt)
        end
      end
    end
    return rawAdvance(runtime, provider)
  end
  clockPatched = setUpvalue(playerPose, advanceIndex, motionAdvance)
end

-- -------------------------------------------------------------------------
-- Whole-model movement presentation.  The original matrix is retained as the
-- safety oracle; if it says the mount should not draw, we do not draw either.
-- We then rebuild the same T*Yaw*Scale*Floor matrix with a small local
-- roll/pitch and world-space bob inserted.  ShadowMap receives the identical
-- matrix so the animated mount and its shadow cannot diverge.
-- -------------------------------------------------------------------------
local function rotateX(a)
  local c, s = math.cos(a), math.sin(a)
  return { 1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1 }
end

local function rotateZ(a)
  local c, s = math.cos(a), math.sin(a)
  return { c,-s,0,0, s,c,0,0, 0,0,1,0, 0,0,0,1 }
end

local function faceYaw(facing)
  if facing == "up" then return math.pi end
  if facing == "right" then return math.pi / 2 end
  if facing == "left" then return -math.pi / 2 end
  return 0
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

local function rebuildMatrix(runtime, provider, rawModelMatrix)
  local safe = rawModelMatrix(runtime, provider)
  if not safe then return nil end
  local role, species = roleFor(runtime)
  local profile = role and profileFor(role, species, runtime and runtime.dex) or nil
  if not profile then return safe end
  local Mat4 = provider and provider.Mat4 or nil
  if not (Mat4 and type(Mat4.mul) == "function" and type(Mat4.translate) == "function"
      and type(Mat4.rotateY) == "function" and type(Mat4.scale) == "function") then
    return safe
  end
  local ow = Game and Game.overworld or nil
  local player = ow and ow.player or nil
  local model = runtime and runtime.model or nil
  if not (ow and player and model) then return safe end

  local s = sampleMotion(runtime, role, profile)
  local baseY
  if flight and flight.active and flight.species == species then
    baseY = tonumber(flight.altitude) or 0
  else
    baseY = 0
    if ow.map and type(terrainGroundHeight) == "function" then
      local ok, value = pcall(terrainGroundHeight, ow.map, player.cellX, player.cellY)
      if ok and tonumber(value) then baseY = tonumber(value) end
    end
  end

  local root = tonumber(model.rootScale) or 1
  if root <= 0 then root = 1 end
  local rawHeight = tonumber(model.height) or 1
  if rawHeight <= 0 then rawHeight = 1 end
  local scale = root * (16 * mountScale(species)) / rawHeight
  local rawFloor = (tonumber(model.floor) or 0) / root
  local yaw = faceYaw(player.facing)

  local m = Mat4.translate((tonumber(player.px) or 0) + 8,
    baseY + (s.bob or 0), (tonumber(player.py) or 0) + 8)
  m = Mat4.mul(m, Mat4.rotateY(yaw))
  m = Mat4.mul(m, rotateZ(s.roll or 0))
  m = Mat4.mul(m, rotateX(s.pitch or 0))
  m = Mat4.mul(m, Mat4.scale(scale, scale, scale))
  m = Mat4.mul(m, Mat4.translate(0, -rawFloor, 0))
  return m
end

local _, providerModules = findUpvalue(playerPose, "providerModules")
local provider = type(providerModules) == "function" and providerModules() or nil

local matrixPatched, shadowPatched = false, false
if provider and provider.Voxel3D and type(provider.Voxel3D.draw) == "function" then
  local idx, raw = findUpvalue(provider.Voxel3D.draw, "modelMatrix")
  if idx and type(raw) == "function" then
    local function motionModelMatrix(runtime, activeProvider)
      return rebuildMatrix(runtime, activeProvider, raw)
    end
    matrixPatched = setUpvalue(provider.Voxel3D.draw, idx, motionModelMatrix)
  end
end
if provider and provider.ShadowMap and type(provider.ShadowMap.draw) == "function" then
  local idx, raw = findUpvalue(provider.ShadowMap.draw, "modelMatrix")
  if idx and type(raw) == "function" then
    local function motionShadowMatrix(runtime, activeProvider)
      return rebuildMatrix(runtime, activeProvider, raw)
    end
    shadowPatched = setUpvalue(provider.ShadowMap.draw, idx, motionShadowMatrix)
  end
end

local function coverageList(set)
  local out = {}
  for species, profile in pairs(set) do
    out[#out+1] = { species=species, dex=DEX[species], family=profile.family }
  end
  table.sort(out, function(a,b) return (a.dex or 999) < (b.dex or 999) end)
  return out
end

mod.exports.stadium3DMountMotion = {
  api = 1,
  installed = clockPatched,
  matrixPatched = matrixPatched,
  shadowPatched = shadowPatched,
  coverage = function()
    return {
      flight=coverageList(FLIGHT), ground=coverageList(GROUND), water=coverageList(WATER),
      counts={ flight=16, ground=17, water=8, roleEntries=41 },
    }
  end,
  profile = function(role, species, dex)
    return profileFor(role, species, dex)
  end,
  stats = function(dex)
    if dex then return statsByDex[tonumber(dex)] end
    return statsByDex
  end,
}

if clockPatched then
  log("Stadium 2 mount motion loaded (16 Flight + 17 Ground + 8 Surf profiles; matrix=%s shadow=%s)",
    tostring(matrixPatched), tostring(shadowPatched))
else
  warnOnce("clock", "Stadium 2 mount motion could not attach to alpha.7 render clock")
end
if not matrixPatched then
  warnOnce("matrix", "Stadium 2 mount motion could not patch Voxel3D model transforms; skeleton cadence remains active")
end
if provider and provider.ShadowMap and not shadowPatched then
  warnOnce("shadow", "Stadium 2 mount motion could not mirror transforms into ShadowMap")
end
end)();
