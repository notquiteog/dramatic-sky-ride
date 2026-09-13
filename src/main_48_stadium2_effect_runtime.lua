(function()
-- -------------------------------------------------------------------------
-- Stadium 2 effect flipbook runtime.
--
-- main_47 restores prim.fxFrames from DSM4. Apply those generated texture
-- sequences after whichever skeletal path owns the frame (provider StadiumRig
-- or DSR's interpolated fallback). Keeping this as the final pose decorator
-- means Battle Art and Dramaless produce the same Charizard/Ponyta/Gastly
-- effect animation without duplicating skeleton logic.
-- -------------------------------------------------------------------------

local MODEL_FPS = 30
local warned = {}

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

local function makeTexture(slot)
  if not slot then return nil end
  if slot.image ~= nil then return slot.image or nil end
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then
    slot.image = false
    return nil
  end
  local ok, image = pcall(function()
    local data = love.image.newImageData(slot.w, slot.h, "rgba8", slot.rgba)
    local out = love.graphics.newImage(data)
    if out.setFilter then out:setFilter("nearest", "nearest") end
    return out
  end)
  slot.image = ok and image or false
  return slot.image or nil
end

local function apply(runtime)
  local model = runtime and runtime.model
  if not (model and model.textures) then return 0 end
  local tick = math.floor(math.max(0, tonumber(runtime.time) or 0) * MODEL_FPS)
  local active = 0
  for _, part in ipairs(runtime.parts or {}) do
    local prim = part.prim
    local frames = prim and prim.fxFrames
    if type(frames) == "table" and #frames > 0 then
      local index = frames[(tick % #frames) + 1]
      local texture = model.textures[index]
      if texture then
        part.texture = makeTexture(texture)
        active = active + 1
      end
    end
  end
  model._dsrFxActiveParts = active
  model._dsrFxTick = tick
  return active
end

local _, ensureWrapper = findUpvalue(Player and Player.pose, "ensureRuntime")
local _, rawEnsureRuntime = findUpvalue(ensureWrapper, "rawEnsureRuntime")
if type(rawEnsureRuntime) ~= "function" then rawEnsureRuntime = ensureWrapper end
local ensurePoseIndex, previousPoseRuntime = findUpvalue(rawEnsureRuntime, "poseRuntime")
local updatePoseIndex, updatePoseRuntime = findUpvalue(
  OverworldState and OverworldState.update, "poseRuntime")

-- Both seams should point at main_45's hybrid function. Refuse to create a
-- split-brain decorator when another late mod has changed only one of them.
local samePose = type(previousPoseRuntime) == "function"
  and previousPoseRuntime == updatePoseRuntime
local installed = false
if samePose then
  local function effectPoseRuntime(runtime, provider)
    local ok = previousPoseRuntime(runtime, provider)
    if ok then apply(runtime) end
    return ok
  end
  local a = setUpvalue(rawEnsureRuntime, ensurePoseIndex, effectPoseRuntime)
  local b = setUpvalue(OverworldState.update, updatePoseIndex, effectPoseRuntime)
  installed = a and b
  if not installed then
    -- Roll back any one-sided write immediately.
    if a then setUpvalue(rawEnsureRuntime, ensurePoseIndex, previousPoseRuntime) end
    if b then setUpvalue(OverworldState.update, updatePoseIndex, updatePoseRuntime) end
  end
end

local fx = mod.exports and mod.exports.stadium3DEffects or nil
if type(fx) ~= "table" then
  fx = { api = 1 }
  mod.exports.stadium3DEffects = fx
end
fx.api = 2
fx.runtimePatched = installed
fx.fps = MODEL_FPS
fx.apply = apply
fx.status = function()
  return {
    parsePatched = fx.parsePatched == true,
    runtimePatched = installed,
    fps = MODEL_FPS,
  }
end

if installed then
  log("Stadium 2 effect flipbook runtime loaded (30 Hz procedural textures)")
else
  warnOnce("install", "Stadium 2 effect flipbook runtime could not install on both pose seams")
end
end)();
