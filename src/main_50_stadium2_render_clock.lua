(function()
-- -------------------------------------------------------------------------
-- Stadium 2 render-path animation driver.
--
-- The native mount is requested through Player:pose(), while the first
-- experimental animation clock was driven from OverworldState:update().  In
-- some provider/load-order combinations the model can therefore be rendered
-- successfully even though that update seam is not the one advancing the
-- native runtime.  The symptom is unambiguous: valid DSM4 skeletal tracks,
-- intact 3D geometry, but a permanently frozen bind/first pose.
--
-- Make the visible path authoritative.  Once Player:pose() has resolved a
-- native Stadium mount, advance a small monotonic render clock and pose/skin
-- the same runtime before the sprite sentinel is consumed by Voxel3D.  Shadow
-- and reflection passes can ask for Player:pose() more than once per display
-- frame, so very small wall-clock deltas are folded into the same pose sample
-- instead of multiplying animation speed.
-- -------------------------------------------------------------------------

local MAX_WALL_DT = 0.10
local MIN_REPOSE_DT = 1 / 240
local warned = {}
local stateByDex = {}

local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
end

local function findUpvalue(fn, wanted)
  if type(fn) ~= "function" or not (debug and debug.getupvalue) then return nil end
  for index = 1, 128 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return index, value end
  end
  return nil
end

local previousPose = Player and Player.pose or nil
local _, ensureRuntime = findUpvalue(previousPose, "ensureRuntime")
local _, currentMount = findUpvalue(previousPose, "currentMount")

-- Hardening wraps ensureRuntime.  The raw function owns the mutable poseRuntime
-- seam that main_43/45/48/49 progressively decorated, so using its CURRENT
-- upvalue preserves provider StadiumRig, fallback interpolation, effect frames
-- and moving-track recovery rather than bypassing any of them.
local _, rawEnsureRuntime = findUpvalue(ensureRuntime, "rawEnsureRuntime")
if type(rawEnsureRuntime) ~= "function" then rawEnsureRuntime = ensureRuntime end
local _, poseRuntime = findUpvalue(rawEnsureRuntime, "poseRuntime")
local _, providerModules = findUpvalue(rawEnsureRuntime, "providerModules")

local function nowSeconds()
  if love and love.timer and type(love.timer.getTime) == "function" then
    local ok, value = pcall(love.timer.getTime)
    value = ok and tonumber(value) or nil
    if value then return value end
  end
  return nil
end

local function nativeSprite(sprite)
  local def = sprite and sprite.def
  return def and def.dramaticSkyRideStadiumNative == true
end

local function advance(runtime, provider)
  if not (runtime and type(poseRuntime) == "function" and provider) then return false end
  local now = nowSeconds()
  if not now then return false end

  if runtime._dsrRenderClockNow == nil then
    runtime._dsrRenderClockNow = now
    runtime._dsrRenderClockTime = math.max(0, tonumber(runtime.time) or 0)
    runtime._dsrRenderClockPoseNow = nil
  else
    local dt = now - runtime._dsrRenderClockNow
    runtime._dsrRenderClockNow = now
    if dt < 0 then dt = 0 end
    if dt > MAX_WALL_DT then dt = MAX_WALL_DT end
    runtime._dsrRenderClockTime = math.max(0,
      tonumber(runtime._dsrRenderClockTime) or tonumber(runtime.time) or 0) + dt
  end

  -- Overwrite the update-driven clock rather than adding to it.  This prevents
  -- a provider where BOTH seams happen to work from running at double speed.
  runtime.time = runtime._dsrRenderClockTime or 0

  local lastPose = runtime._dsrRenderClockPoseNow
  if lastPose and now - lastPose >= 0 and now - lastPose < MIN_REPOSE_DT then
    return true
  end
  runtime._dsrRenderClockPoseNow = now

  local ok, result = pcall(poseRuntime, runtime, provider)
  if not ok then
    warnOnce("pose:" .. tostring(runtime.dex),
      "Render-driven Stadium 2 pose failed for #%03d: %s",
      tonumber(runtime.dex) or 0, tostring(result))
    return false
  end

  if runtime.dex then
    stateByDex[runtime.dex] = {
      dex = runtime.dex,
      time = runtime.time,
      anim = runtime.anim,
      frame = runtime.frame,
      providerRig = runtime.providerRig == true,
      wall = now,
      ok = result ~= false,
    }
  end
  return result ~= false
end

local installed = type(previousPose) == "function"
  and type(ensureRuntime) == "function"
  and type(currentMount) == "function"
  and type(poseRuntime) == "function"
  and type(providerModules) == "function"

if installed then
  function Player:pose(...)
    local sprite, px, py, facing, phase, flip, hopping = previousPose(self, ...)
    if nativeSprite(sprite) then
      local okMount, kind, species, mon = pcall(currentMount)
      if okMount and kind and species then
        local okRuntime, runtime = pcall(ensureRuntime, species, mon)
        if okRuntime and runtime then
          runtime.facing = facing or self.facing or runtime.facing or "down"
          local okProvider, provider = pcall(providerModules)
          if okProvider and provider then advance(runtime, provider) end
        end
      end
    end
    return sprite, px, py, facing, phase, flip, hopping
  end
end

mod.exports.stadium3DRenderClock = {
  api = 1,
  installed = installed,
  maxWallDt = MAX_WALL_DT,
  minReposeDt = MIN_REPOSE_DT,
  stats = function(dex)
    if dex then return stateByDex[tonumber(dex)] end
    return stateByDex
  end,
}

if installed then
  log("Stadium 2 render-path animation driver loaded")
else
  warnOnce("install",
    "Stadium 2 render-path animation driver could not resolve the native pose seams")
end
end)();
