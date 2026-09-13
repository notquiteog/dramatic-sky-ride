
;(function()

-- Alpha.15: Ground Ride polish, visible Surf mounts,
-- mount browser and strict alpha.14 flight-camera preservation.
local Sound = require("src.core.Sound")

local function mountOption(key, default)
  return optionValue(key, default)
end

local function mountSpeedMultiplier(key)
  local percent = tonumber(mountOption(key, 100)) or 100
  percent = math.max(50, math.min(200, percent))
  return percent / 100
end

local MOUNT_OPTION_SCHEMA = {
    { key = "mount_cries", type = "toggle", label = "MOUNT CRIES", default = true,
      help = "Play the selected Pokemon's cry when mounting or taking off." },
    { key = "ground_gallop", type = "toggle", label = "GROUND GALLOP", default = true,
      help = "Hold B to gallop while stamina remains." },
    { key = "ground_dust", type = "toggle", label = "GROUND DUST", default = true,
      help = "Show dust at the mount's feet while travelling quickly." },
    { key = "ground_hud", type = "toggle", label = "GROUND HUD", default = true,
      help = "Show the Ground Ride stamina gauge while galloping." },
    { key = "reverse_ledge_jumps", type = "toggle", label = "TWO-WAY LEDGES", default = true,
      help = "Allow Ground Ride to jump official low ledges in reverse." },
    { key = "remount_after_battle", type = "toggle", label = "REMOUNT AFTER BATTLE", default = true,
      help = "Restore Flight, Ground Ride or Visible Surf after battle when the mount remains usable." },
    { key = "visible_surf_mounts", type = "toggle", label = "VISIBLE SURF MOUNTS", default = true,
      help = "Show compatible Surf Pokemon instead of the generic Surf sprite." },
    { key = "mount_menu", type = "toggle", label = "MOUNTS MENU", default = true,
      help = "Add a MOUNTS entry to the START menu." },
    { key = "mount_hints", type = "toggle", label = "MOUNT HINTS", default = true,
      help = "Show a short control reminder the first time each ride type is used." },
}

for _, row in ipairs(MOUNT_OPTION_SCHEMA) do
  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = row
end
if mod.options and mod.options.define then
  mod.options:define(OPTION_SCHEMA)
end

local GROUND_PROFILES = {
  ARCANINE   = { base = 1.12, gallop = 1.34, accel = 3.2, drain = 0.25, regen = 0.20,
                 lift = 6.8, forward = 0.35, eye = 18.0, shadow = 0.95 },
  RAPIDASH   = { base = 1.10, gallop = 1.42, accel = 3.0, drain = 0.27, regen = 0.20,
                 lift = 7.1, forward = 0.35, eye = 18.5, shadow = 0.92 },
  DODRIO     = { base = 1.13, gallop = 1.31, accel = 3.6, drain = 0.23, regen = 0.22,
                 lift = 7.2, forward = 0.25, eye = 19.0, shadow = 0.88 },
  RHYHORN    = { base = 0.91, gallop = 1.18, accel = 1.7, drain = 0.18, regen = 0.24,
                 lift = 6.2, forward = 0.15, eye = 17.5, shadow = 1.12 },
  RHYDON     = { base = 0.89, gallop = 1.16, accel = 1.6, drain = 0.18, regen = 0.24,
                 lift = 7.4, forward = 0.10, eye = 20.0, shadow = 1.16 },
  KANGASKHAN = { base = 0.99, gallop = 1.23, accel = 2.2, drain = 0.21, regen = 0.22,
                 lift = 7.8, forward = 0.10, eye = 20.0, shadow = 1.04 },
  TAUROS     = { base = 1.06, gallop = 1.39, accel = 3.5, drain = 0.28, regen = 0.19,
                 lift = 6.7, forward = 0.40, eye = 18.0, shadow = 1.00 },
  SNORLAX    = { base = 0.45, gallop = 1.08, accel = 0.7, drain = 0.08, regen = 0.30,
                 lift = 8.6, forward = -0.10, eye = 20.5, shadow = 1.30 },
}


-- Snorlax is the one deliberately silly extra terrestrial mount.
GROUND_ELIGIBLE.SNORLAX = { dex = 143, label = "SNORLAX", lift = 8.6 }
GROUND_BY_DEX[143] = "SNORLAX"

-- Flight camera, rider offsets and eye height intentionally remain untouched.

local function playSpeciesCry(species)
  if mountOption("mount_cries", true) ~= true or not species then return end
  pcall(Sound.playCry, Game.data, species)
end

local mountHintsShown = { ground = false, flight = false, water = false }
local function groundNotice(text, seconds)
  ground.notice = text
  ground.noticeTimer = seconds or 1.8
end

-- Ground Ride follower restoration is provided by main_16_ground_followers.lua.
local alpha14StartGroundRide = startGroundRide
startGroundRide = function(game, mon)
  local ok = alpha14StartGroundRide(game, mon)
  if not ok then return ok end
  ground.stamina = 1
  ground.speedBlend = 0
  ground.gallop = false
  local world = mod.exports._mountWorld(game)
  ground.lastCellX = world.player.cellX
  ground.lastCellY = world.player.cellY
  ground.stepCounter = 0
  ground.dustDistance = 0
  ground.movingContinuous = false
  playSpeciesCry(ground.species)
  if mountOption("mount_hints", true) and not mountHintsShown.ground then
    mountHintsShown.ground = true
    local provider = mod.exports and mod.exports._dramaticProviderState or nil
    local key = provider and provider.id == "DRAMALESS_SHAPE" and "J" or "G"
    groundNotice(key .. " DISMOUNT  B GALLOP", 3.0)
  end
  return true
end

local alpha14StartFlight = startFlight
startFlight = function(game, mon)
  local ok = alpha14StartFlight(game, mon)
  if ok then
    -- Audio and a one-shot hint are the only alpha.15 additions here.
    -- Flight movement, altitude, rider offsets and camera behaviour are not
    -- changed by this wrapper.
    playSpeciesCry(flight.species)
    if mountOption("mount_hints", true) and not mountHintsShown.flight then
      mountHintsShown.flight = true
      notifyHud("H LAND  B BOOST", 3.0)
    end
  end
  return ok
end

-- Ground rider position and procedural lean/bounce.
groundRiderPose = function(entity)
  local ow = Game.overworld
  local p = ow and ow.player
  if not (ground.active and p and ground.riderSprite) then
    return entity.sprite, entity.px or 0, entity.py or 0,
      entity.facing or "down", 0, false, false
  end
  local cfg = GROUND_PROFILES[ground.species] or { lift = 6.5, forward = 0 }
  local d = FACING_DELTA[p.facing] or FACING_DELTA.down
  local moving = ground.movingContinuous or p.moving or p.stepLanded
  local cadence = ground.gallop and 8 or 16
  local phase = math.floor((p.animClock or 0) / cadence) % 2
  local bounce = moving and (phase == 1 and 0.7 or 0) or 0
  local lean = (ground.speedBlend or 0) * (cfg.forward or 0)
  entity.cellX, entity.cellY = p.cellX, p.cellY
  entity.px = p.px + d[1] * lean
  entity.py = p.py + d[2] * lean
  entity.facing = p.facing
  return ground.riderSprite, entity.px, entity.py - cfg.lift - bounce,
    p.facing, phase, false, p.hopFrames and p.hopFrames > 0 or false
end

groundRiderDraw = function(entity, camX, camY)
  local sprite, px, py, facing, phase, flip = groundRiderPose(entity)
  if sprite and sprite.draw then sprite:draw(px, py, camX, camY, facing, phase, flip) end
end

-- Replace the reverse-ledge wrapper so the option can disable only the reverse
-- direction while native ledges continue to work.
local function cellHasWarp(map, x, y)
  for _, warp in ipairs(map and map.def and map.def.warps or {}) do
    if tonumber(warp.x) == x and tonumber(warp.y) == y then return true end
  end
