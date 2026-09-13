(function()
-- -------------------------------------------------------------------------
-- Interpolated Stadium 2 fallback for providers without StadiumRig.
--
-- Battle Art is DSR's recommended voxel provider but does not currently
-- expose the StadiumRig module Dramaless provides. Native Stadium 2 must not
-- therefore regress to a visibly stepped 30 Hz skeleton on the recommended
-- setup. This layer upgrades main_41's fallback while retaining its meshes,
-- draw hooks and cache ownership.
-- -------------------------------------------------------------------------

local MODEL_FPS = 30
local BREAK_ANGLE = 16384
local BREAK_MOVE = 0.5
local TRAVEL_LIMIT = 0.75
local ANCHOR_STEADY = 0.5
local ANCHOR_HALF_LIFE = 0.05
local NONE16 = 0xFFFF
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

local _, ensureWrapper = findUpvalue(Player and Player.pose, "ensureRuntime")
local _, rawEnsureRuntime = findUpvalue(ensureWrapper, "rawEnsureRuntime")
if type(rawEnsureRuntime) ~= "function" then rawEnsureRuntime = ensureWrapper end
local ensurePoseIndex, currentPoseRuntime = findUpvalue(rawEnsureRuntime, "poseRuntime")
local updatePoseIndex = select(1, findUpvalue(
  OverworldState and OverworldState.update, "poseRuntime"))

-- If main_43 installed the provider bridge, currentPoseRuntime is its wrapper
-- and the original main_41 pose function is retained inside it. Otherwise the
-- current function is already main_41's pose function.
local _, basePoseRuntime = findUpvalue(currentPoseRuntime, "rawPoseRuntime")
if type(basePoseRuntime) ~= "function" then basePoseRuntime = currentPoseRuntime end
local _, tracksFor = findUpvalue(basePoseRuntime, "tracksFor")

local function sampleAt(component, index)
  if type(component) == "number" then return component end
  if type(component) ~= "table" then return 0 end
  return component[index] or component[#component] or 0
end

local function angleDelta(component, i0, i1)
  if type(component) == "number" then return 0 end
  local d = sampleAt(component, i1) - sampleAt(component, i0)
  if d > 32768 then d = d - 65536 elseif d < -32768 then d = d + 65536 end
  return d
end

local function linearDelta(component, i0, i1)
  if type(component) == "number" then return 0 end
  return sampleAt(component, i1) - sampleAt(component, i0)
end

local function framePair(record, elapsed)
  local frames = math.max(1, tonumber(record and record.frames) or 1)
  if frames <= 1 then return 1, 1, 0, 0 end
  local frame = math.max(0, tonumber(elapsed) or 0) * MODEL_FPS
  local base = math.floor(frame)
  local blend = frame - base
  local loop = tonumber(record and record.loopStart) or 0
  if not (loop > 0 and loop < frames) then loop = 0 end
  if base >= frames then base = loop + (base - loop) % (frames - loop) end
  local i0 = math.max(1, math.min(frames, base + 1))
  local i1 = i0 < frames and (i0 + 1) or (loop + 1)
  return i0, i1, blend, i0 - 1
end

-- Same N64 Euler basis used by StadiumRig / the Stadium game data.
local function rotation3(rx, ry, rz)
  local ax = (tonumber(rx) or 0) * math.pi / 32768
  local ay = (tonumber(ry) or 0) * math.pi / 32768
  local az = (tonumber(rz) or 0) * math.pi / 32768
  local sx, cx = math.sin(ax), math.cos(ax)
  local sy, cy = math.sin(ay), math.cos(ay)
  local sz, cz = math.sin(az), math.cos(az)
  return {
    cy * cz, sx * sy * cz - cx * sz, cx * sy * cz + sx * sz,
    cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - sx * cz,
    -sy,     sx * cy,                cx * cy,
  }
end

local function compose34(parent, r, tx, ty, tz)
  if not parent then
    return { r[1],r[2],r[3],tx, r[4],r[5],r[6],ty, r[7],r[8],r[9],tz }
  end
  return {
    parent[1]*r[1]+parent[2]*r[4]+parent[3]*r[7],
    parent[1]*r[2]+parent[2]*r[5]+parent[3]*r[8],
    parent[1]*r[3]+parent[2]*r[6]+parent[3]*r[9],
    parent[1]*tx+parent[2]*ty+parent[3]*tz+parent[4],
    parent[5]*r[1]+parent[6]*r[4]+parent[7]*r[7],
    parent[5]*r[2]+parent[6]*r[5]+parent[7]*r[8],
    parent[5]*r[3]+parent[6]*r[6]+parent[7]*r[9],
    parent[5]*tx+parent[6]*ty+parent[7]*tz+parent[8],
    parent[9]*r[1]+parent[10]*r[4]+parent[11]*r[7],
    parent[9]*r[2]+parent[10]*r[5]+parent[11]*r[8],
    parent[9]*r[3]+parent[10]*r[6]+parent[11]*r[9],
    parent[9]*tx+parent[10]*ty+parent[11]*tz+parent[12],
  }
end

local function faceYaw(facing)
  if facing == "up" then return math.pi end
  if facing == "right" then return math.pi / 2 end
  if facing == "left" then return -math.pi / 2 end
  return 0
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

local function boneWeights(model)
  if model._dsrMountBoneWeights then
    return model._dsrMountBoneWeights, model._dsrMountBoneWeightTotal
  end
  local weights, total = {}, 0
  for bone = 1, tonumber(model.boneCount) or 0 do weights[bone] = 0 end
  for _, prim in ipairs(model.prims or {}) do
    for vertex = 1, tonumber(prim.vertCount) or 0 do
      local bone = prim.bone and prim.bone[vertex]
      if bone and weights[bone] ~= nil then
        weights[bone] = weights[bone] + 1
        total = total + 1
      end
    end
  end
  model._dsrMountBoneWeights = weights
  model._dsrMountBoneWeightTotal = total
  return weights, total
end

local function bodyCentre(runtime)
  local model = runtime.model
  local weights, total = boneWeights(model)
  if not (total and total > 0) then return nil end
  local x, y, z = 0, 0, 0
  for bone = 1, tonumber(model.boneCount) or 0 do
    local weight = weights[bone] or 0
    local matrix = runtime.drawM and runtime.drawM[bone]
    if weight > 0 and matrix then
      x = x + matrix[4] * weight
      y = y + matrix[8] * weight
      z = z + matrix[12] * weight
    end
  end
  return x / total, y / total, z / total
end

local function anchorPose(runtime, dt)
  local model = runtime.model
  local root = tonumber(model.rootScale) or 1
  if root <= 0 then root = 1 end
  local height = (tonumber(model.height) or 0) / root
  if height <= 0 then return end
  local x, y, z = bodyCentre(runtime)
  if not x then return end

  if not runtime._dsrAnchorX then
    runtime._dsrAnchorX, runtime._dsrAnchorY, runtime._dsrAnchorZ = x, y, z
    runtime._dsrAnchorPrevX, runtime._dsrAnchorPrevY, runtime._dsrAnchorPrevZ = x, y, z
    return
  end

  local px, py, pz = runtime._dsrAnchorPrevX, runtime._dsrAnchorPrevY,
    runtime._dsrAnchorPrevZ
  if px then
    local step = ((x-px)^2 + (y-py)^2 + (z-pz)^2)^0.5 / height
    if step > ANCHOR_STEADY then
      runtime._dsrAnchorDisabled = true
      runtime._dsrAnchorOffsetX, runtime._dsrAnchorOffsetY,
        runtime._dsrAnchorOffsetZ = 0, 0, 0
      warnOnce("anchor:" .. tostring(runtime.dex),
        "Stadium 2 model #%s moves its body %.2f heights in one frame; mount anchoring disabled for this model",
        tostring(runtime.dex), step)
    end
  end
  runtime._dsrAnchorPrevX, runtime._dsrAnchorPrevY, runtime._dsrAnchorPrevZ = x, y, z
  if runtime._dsrAnchorDisabled then return end

  local dx = x - runtime._dsrAnchorX
  local dy = y - runtime._dsrAnchorY
  local dz = z - runtime._dsrAnchorZ
  local dist = (dx*dx + dy*dy + dz*dz)^0.5
  local allow = TRAVEL_LIMIT * height
  local ox, oy, oz = 0, 0, 0
  if dist > allow and dist > 0 then
    local amount = (dist - allow) / dist
    ox, oy, oz = dx * amount, dy * amount, dz * amount
  end

  if dt and dt > 0 then
    local a = 1 - 0.5 ^ (dt / ANCHOR_HALF_LIFE)
    local oldX = runtime._dsrAnchorOffsetX
    local oldY = runtime._dsrAnchorOffsetY
    local oldZ = runtime._dsrAnchorOffsetZ
    if oldX ~= nil then
      ox = oldX + (ox - oldX) * a
      oy = oldY + (oy - oldY) * a
      oz = oldZ + (oz - oldZ) * a
    end
  end
  runtime._dsrAnchorOffsetX, runtime._dsrAnchorOffsetY,
    runtime._dsrAnchorOffsetZ = ox, oy, oz
  if ox == 0 and oy == 0 and oz == 0 then return end

  for bone = 1, tonumber(model.boneCount) or 0 do
    local pivot = runtime.pivot and runtime.pivot[bone]
    local draw = runtime.drawM and runtime.drawM[bone]
    if pivot then
      pivot[4], pivot[8], pivot[12] = pivot[4]-ox, pivot[8]-oy, pivot[12]-oz
    end
    if draw then
      draw[4], draw[8], draw[12] = draw[4]-ox, draw[8]-oy, draw[12]-oz
    end
  end
end

local function interpolatedFallback(runtime, provider)
  if not (runtime and runtime.model and type(tracksFor) == "function") then
    return type(basePoseRuntime) == "function"
      and basePoseRuntime(runtime, provider) or false
  end
  local model = runtime.model
  runtime.pivot = runtime.pivot or {}
  runtime.drawM = runtime.drawM or {}
  runtime.accX = runtime.accX or {}
  runtime.accY = runtime.accY or {}
  runtime.accZ = runtime.accZ or {}

  local elapsed = math.max(0, tonumber(runtime.time) or 0)
  local previousTime = tonumber(runtime._dsrFallbackPoseTime) or elapsed
  local dt = math.max(0, elapsed - previousTime)
  if runtime._dsrFallbackPoseTime == elapsed
      and runtime._dsrFallbackFacing == runtime.facing then return true end
  runtime._dsrFallbackPoseTime = elapsed
  runtime._dsrFallbackFacing = runtime.facing

  local anim = runtime.anim
  local record = anim and model.anims and model.anims[anim] or nil
  local tracks = anim and tracksFor(model, anim) or nil
  local i0, i1, blend, frameAt = framePair(record, elapsed)
  local root = tonumber(model.rootScale) or 1
  if root <= 0 then root = 1 end
  local rawHeight = (tonumber(model.height) or 0) / root
  local moveBreak = rawHeight > 0 and rawHeight * BREAK_MOVE or nil

  for bone = 1, tonumber(model.boneCount) or 0 do
    local o = (bone - 1) * 3
    local tx, ty, tz = model.restT[o+1], model.restT[o+2], model.restT[o+3]
    local rx, ry, rz = model.restR[o+1], model.restR[o+2], model.restR[o+3]
    local sx, sy, sz = model.restS[o+1], model.restS[o+2], model.restS[o+3]
    local c = tracks and tracks[bone]
    if c then
      tx, ty, tz = sampleAt(c[1], i0), sampleAt(c[2], i0), sampleAt(c[3], i0)
      rx, ry, rz = sampleAt(c[4], i0), sampleAt(c[5], i0), sampleAt(c[6], i0)
      sx, sy, sz = sampleAt(c[7], i0), sampleAt(c[8], i0), sampleAt(c[9], i0)
      if blend > 0 then
        local arx, ary, arz = angleDelta(c[4], i0, i1),
          angleDelta(c[5], i0, i1), angleDelta(c[6], i0, i1)
        if math.abs(arx) <= BREAK_ANGLE and math.abs(ary) <= BREAK_ANGLE
            and math.abs(arz) <= BREAK_ANGLE then
          rx, ry, rz = rx + arx*blend, ry + ary*blend, rz + arz*blend
        end
        local mx, my, mz = linearDelta(c[1], i0, i1),
          linearDelta(c[2], i0, i1), linearDelta(c[3], i0, i1)
        local teleport = moveBreak and (math.abs(mx) > moveBreak
          or math.abs(my) > moveBreak or math.abs(mz) > moveBreak)
        if not teleport then
          tx, ty, tz = tx + mx*blend, ty + my*blend, tz + mz*blend
        end
        sx = sx + linearDelta(c[7], i0, i1)*blend
        sy = sy + linearDelta(c[8], i0, i1)*blend
        sz = sz + linearDelta(c[9], i0, i1)*blend
      end
    end

    local parentIndex = model.parent[bone] or 0
    local parentPivot = parentIndex > 0 and runtime.pivot[parentIndex] or nil
    local psx, psy, psz = 1, 1, 1
    if parentIndex > 0 then
      psx, psy, psz = runtime.accX[parentIndex] or 1,
        runtime.accY[parentIndex] or 1, runtime.accZ[parentIndex] or 1
    end
    tx, ty, tz = tx * psx, ty * psy, tz * psz
    local pivot = compose34(parentPivot, rotation3(rx, ry, rz), tx, ty, tz)
    runtime.pivot[bone] = pivot
    local ax, ay, az = psx*sx, psy*sy, psz*sz
    runtime.accX[bone], runtime.accY[bone], runtime.accZ[bone] = ax, ay, az
    runtime.drawM[bone] = {
      pivot[1]*ax,pivot[2]*ay,pivot[3]*az,pivot[4],
      pivot[5]*ax,pivot[6]*ay,pivot[7]*az,pivot[8],
      pivot[9]*ax,pivot[10]*ay,pivot[11]*az,pivot[12],
    }
  end

  anchorPose(runtime, dt)

  local yaw = faceYaw(runtime.facing)
  local cy, syaw = math.cos(yaw), math.sin(yaw)
  for _, part in ipairs(runtime.parts or {}) do
    local prim, rows = part.prim, part.rows
    for vertex = 1, tonumber(prim.vertCount) or 0 do
      local bone = prim.bone[vertex]
      local draw, pivot = runtime.drawM[bone], runtime.pivot[bone]
      if draw and pivot then
        local x, y, z = prim.px[vertex], prim.py[vertex], prim.pz[vertex]
        local row = rows[vertex]
        row[1] = draw[1]*x+draw[2]*y+draw[3]*z+draw[4]
        row[2] = draw[5]*x+draw[6]*y+draw[7]*z+draw[8]
        row[3] = draw[9]*x+draw[10]*y+draw[11]*z+draw[12]
        local nx, ny, nz = prim.nx[vertex], prim.ny[vertex], prim.nz[vertex]
        local wx = pivot[1]*nx+pivot[2]*ny+pivot[3]*nz
        local wy = pivot[5]*nx+pivot[6]*ny+pivot[7]*nz
        local wz = pivot[9]*nx+pivot[10]*ny+pivot[11]*nz
        local worldX = cy*wx + syaw*wz
        local worldZ = cy*wz - syaw*wx
        local shade = 0.7725 + 0.06*worldX + 0.225*wy + 0.11*worldZ
        row[6] = math.max(0.45, math.min(1.05, shade))
      end
    end
    pcall(part.mesh.setVertices, part.mesh, rows)

    local textureIndex = prim.tex
    local auxIndex = record and record.aux or nil
    local aux = auxIndex and model.auxAnims and model.auxAnims[auxIndex] or nil
    if aux and prim.texAnim and prim.texAnim >= 0 and prim.texMap then
      local stream = aux.channels and aux.channels[prim.texAnim + 1] or nil
      if type(stream) == "table" and #stream > 0 then
        local at = math.max(1, math.min(#stream, frameAt + 1))
        local mapped = prim.texMap[stream[at]]
        if mapped then textureIndex = mapped end
      end
    end
    part.texture = makeTexture(model.textures and model.textures[textureIndex])
  end

  runtime.frame = frameAt
  runtime.posedFacing = runtime.facing
  return true
end

local providerBridge = mod.exports and mod.exports.stadium3DProviderRig or nil
local providerActive = providerBridge and type(providerBridge.active) == "function"
  and providerBridge.active() == true

local function hybridPoseRuntime(runtime, provider)
  if runtime and runtime.providerRig and type(currentPoseRuntime) == "function" then
    return currentPoseRuntime(runtime, provider)
  end
  return interpolatedFallback(runtime, provider)
end

local installed = false
if type(rawEnsureRuntime) == "function" and type(basePoseRuntime) == "function"
    and type(tracksFor) == "function" then
  local a = setUpvalue(rawEnsureRuntime, ensurePoseIndex, hybridPoseRuntime)
  local b = updatePoseIndex and setUpvalue(OverworldState.update,
    updatePoseIndex, hybridPoseRuntime) or false
  installed = a and b
end

mod.exports.stadium3DFallback = {
  api = 1,
  installed = installed,
  interpolated = installed,
  providerRigPreferred = providerActive,
  fps = MODEL_FPS,
  travelLimit = TRAVEL_LIMIT,
}

if installed then
  log("Stadium 2 interpolated fallback loaded (providerRig preferred=%s)",
    tostring(providerActive))
else
  warnOnce("install", "Stadium 2 interpolated fallback could not install; hardened 30 Hz fallback remains")
end
end)();
