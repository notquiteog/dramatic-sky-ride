(function()
-- -------------------------------------------------------------------------
-- Stadium 2 live-animation recovery.
--
-- Crystal 251's Stadium 2 bridge can produce a valid DSM4 containing several
-- decoded motion clips while its provisional context table still points the
-- overworld "idle" slot at a one-frame / constant pose.  That looks exactly
-- like a renderer failure: the model loads perfectly, but never moves.
--
-- This late decorator inspects the ACTUAL packed bone streams.  It keeps the
-- requested idle when that clip really moves; otherwise it selects a genuine
-- moving Stadium clip as an experimental overworld idle.  It also supplies a
-- monotonic-clock fallback only when runtime.time itself failed to advance,
-- making the animation robust to an unusual OverworldState:update dt wrapper.
-- -------------------------------------------------------------------------

local warned = {}
local stateByDex = {}

local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
end

local function findUpvalue(fn, wanted)
  if type(fn) ~= "function" or not (debug and debug.getupvalue) then return nil end
  for index = 1, 96 do
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

local WIDTH = { 2, 2, 2, 2, 2, 2, 4, 4, 4 }

local function byteAt(s, p)
  local value = type(s) == "string" and string.byte(s, p) or nil
  if value == nil then error("animation track exceeds DSM4 payload", 0) end
  return value, p + 1
end

local function dynamicTrackStats(model, index)
  local record = model and model.anims and model.anims[index]
  local bytes = model and model.bytes
  if not (record and type(bytes) == "string" and tonumber(record.offset)) then
    return { dynamic=false, frames=record and tonumber(record.frames) or 0,
      bones=0, components=0, trackedBones=0 }
  end

  local frames = math.max(1, tonumber(record.frames) or 1)
  local p = tonumber(record.offset)
  local dynamicBones, dynamicComponents, trackedBones = 0, 0, 0

  for _ = 1, tonumber(model.boneCount) or 0 do
    local present
    present, p = byteAt(bytes, p)
    if present ~= 0 then
      trackedBones = trackedBones + 1
      local boneMoves = false
      for component = 1, 9 do
        local kind
        kind, p = byteAt(bytes, p)
        local width = WIDTH[component]
        if kind == 0 then
          p = p + width
        else
          local first = bytes:sub(p, p + width - 1)
          local moves = false
          for frame = 2, frames do
            local at = p + (frame - 1) * width
            if bytes:sub(at, at + width - 1) ~= first then moves = true; break end
          end
          if moves then
            boneMoves = true
            dynamicComponents = dynamicComponents + 1
          end
          p = p + width * frames
        end
        if p > #bytes + 1 then error("animation track exceeds DSM4 payload", 0) end
      end
      if boneMoves then dynamicBones = dynamicBones + 1 end
    end
  end

  return {
    dynamic = dynamicBones > 0,
    frames = frames,
    bones = dynamicBones,
    components = dynamicComponents,
    trackedBones = trackedBones,
    loopStart = tonumber(record.loopStart) or 0,
    name = record.name,
  }
end

local function chooseLiveAnimation(runtime)
  if not (runtime and runtime.model) then return nil end
  if runtime._dsrLiveAnimationChecked then return runtime.anim end
  runtime._dsrLiveAnimationChecked = true

  local model = runtime.model
  local requested = tonumber(runtime.anim)
  local requestedStats
  if requested then
    local ok, stats = pcall(dynamicTrackStats, model, requested)
    requestedStats = ok and stats or nil
    if requestedStats and requestedStats.dynamic then
      runtime._dsrLiveAnimationStats = requestedStats
      runtime._dsrLiveAnimationSource = "requested_idle"
      return requested
    end
  end

  local firstDynamic, firstLooping, bestStats
  local firstStats, loopStats
  for index = 1, tonumber(model.animCount) or #(model.anims or {}) do
    local ok, stats = pcall(dynamicTrackStats, model, index)
    if ok and stats and stats.dynamic then
      if not firstDynamic then firstDynamic, firstStats = index, stats end
      -- Prefer a source clip with a non-zero authored loop seam.  If none has
      -- one, the first genuinely moving Stadium clip is still a better test
      -- idle than an immutable bind pose.
      if not firstLooping and stats.loopStart > 0 and stats.loopStart < stats.frames then
        firstLooping, loopStats = index, stats
      end
    end
  end

  local selected = firstLooping or firstDynamic
  bestStats = loopStats or firstStats
  if selected then
    runtime.anim = selected
    runtime.time = 0
    runtime.frame = -1
    runtime.providerPoseTime = nil
    runtime._dsrFallbackPoseTime = nil
    runtime._dsrLiveAnimationStats = bestStats
    runtime._dsrLiveAnimationSource = firstLooping and "moving_loop_recovery"
      or "moving_clip_recovery"
    warnOnce("recover:" .. tostring(runtime.dex),
      "Stadium 2 #%03d idle clip %s is static; using moving clip %d (%s, frames=%d, movingBones=%d)",
      tonumber(runtime.dex) or 0, tostring(requested or "nil"), selected,
      tostring(bestStats and bestStats.name or "unnamed"),
      tonumber(bestStats and bestStats.frames) or 0,
      tonumber(bestStats and bestStats.bones) or 0)
    return selected
  end

  runtime._dsrLiveAnimationStats = requestedStats
  runtime._dsrLiveAnimationSource = "no_moving_tracks"
  warnOnce("nomotion:" .. tostring(runtime.dex),
    "Stadium 2 #%03d contains no changing skeletal tracks; Crystal 251 DSM extraction is still static for this species",
    tonumber(runtime.dex) or 0)
  return runtime.anim
end

local function monotonicNow()
  if love and love.timer and type(love.timer.getTime) == "function" then
    local ok, value = pcall(love.timer.getTime)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return nil
end

local _, ensureWrapper = findUpvalue(Player and Player.pose, "ensureRuntime")
local _, rawEnsureRuntime = findUpvalue(ensureWrapper, "rawEnsureRuntime")
if type(rawEnsureRuntime) ~= "function" then rawEnsureRuntime = ensureWrapper end
local ensurePoseIndex, previousPoseRuntime = findUpvalue(rawEnsureRuntime, "poseRuntime")
local updatePoseIndex, updatePoseRuntime = findUpvalue(
  OverworldState and OverworldState.update, "poseRuntime")

local samePose = type(previousPoseRuntime) == "function"
  and previousPoseRuntime == updatePoseRuntime
local installed = false

if samePose then
  local function livePoseRuntime(runtime, provider)
    chooseLiveAnimation(runtime)

    local now = monotonicNow()
    local current = math.max(0, tonumber(runtime and runtime.time) or 0)
    local last = runtime and runtime._dsrLiveObservedTime or nil
    local lastWall = runtime and runtime._dsrLiveObservedWall or nil
    if runtime and last ~= nil and current <= last + 1e-9 and now and lastWall then
      local wallDt = now - lastWall
      if wallDt > 0 and wallDt < 0.25 then
        runtime.time = current + wallDt
        current = runtime.time
        runtime._dsrLiveClockFallbacks = (runtime._dsrLiveClockFallbacks or 0) + 1
      end
    end
    if runtime then
      runtime._dsrLiveObservedTime = current
      runtime._dsrLiveObservedWall = now
    end

    local ok = previousPoseRuntime(runtime, provider)
    if runtime and runtime.dex then
      local stats = runtime._dsrLiveAnimationStats or {}
      stateByDex[runtime.dex] = {
        dex = runtime.dex,
        anim = runtime.anim,
        source = runtime._dsrLiveAnimationSource,
        frames = stats.frames,
        movingBones = stats.bones,
        movingComponents = stats.components,
        trackedBones = stats.trackedBones,
        clockFallbacks = runtime._dsrLiveClockFallbacks or 0,
        time = runtime.time,
      }
    end
    return ok
  end

  local a = setUpvalue(rawEnsureRuntime, ensurePoseIndex, livePoseRuntime)
  local b = setUpvalue(OverworldState.update, updatePoseIndex, livePoseRuntime)
  installed = a and b
  if not installed then
    if a then setUpvalue(rawEnsureRuntime, ensurePoseIndex, previousPoseRuntime) end
    if b then setUpvalue(OverworldState.update, updatePoseIndex, updatePoseRuntime) end
  end
end

mod.exports.stadium3DLiveAnimation = {
  api = 1,
  installed = installed,
  stats = function(dex)
    if dex then return stateByDex[tonumber(dex)] end
    return stateByDex
  end,
}

if installed then
  log("Stadium 2 live-animation recovery loaded (moving-track selection + clock fallback)")
else
  warnOnce("install", "Stadium 2 live-animation recovery could not install on both pose seams")
end
end)();
