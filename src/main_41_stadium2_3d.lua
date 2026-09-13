(function()
-- -------------------------------------------------------------------------
-- Experimental native Pokemon Stadium 2 mount renderer.
--
-- This layer consumes DSM4 packs generated from the user's own Pokemon
-- Stadium 2 ROM. Crystal 251 already writes those packs to its save-data
-- cache; DSR only reads the generated runtime files and never ships Nintendo
-- model data. Randy's Stadium 1 companion remains an independent fallback.
--
-- The integration deliberately reuses the active voxel provider's public
-- Voxel3D / ShadowMap / SpriteBillboards seam. VoxelScene still owns camera,
-- terrain, depth, reflections, first-person hiding and scene composition.
-- Only a DSR mount card tagged by this module is substituted with skinned 3D
-- geometry, keeping every ordinary NPC/player/follower billboard untouched.
-- -------------------------------------------------------------------------

local CACHE_ROOT = "crystal_251/stadium2"
local NORMAL_DIR = CACHE_ROOT .. "/normal"
local SHINY_DIR = CACHE_ROOT .. "/shiny"
local MARKER = CACHE_ROOT .. "/pack.info"
local PACK_MAGIC = "DSM4"
local NONE16 = 0xFFFF
local MODEL_FPS = 30
local MOVE_SLOTS = 165
local CONTEXT_SLOTS = 20
local CONTEXT_IDLE = 1
local EXPECTED_FORMAT = "C2DSM10"

local runtimeCache = {}
local failedRuntime = {}
local ownerByMesh = setmetatable({}, { __mode = "k" })
local runtimeByDef = setmetatable({}, { __mode = "k" })
local warned = {}

local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
end

local function fileExists(path)
  local fs = love and love.filesystem
  if not (fs and fs.getInfo) then return false end
  local ok, info = pcall(fs.getInfo, path, "file")
  return ok and info ~= nil
end

local function readFile(path)
  local fs = love and love.filesystem
  if not (fs and fs.read) then return nil end
  local ok, bytes = pcall(fs.read, path)
  return ok and type(bytes) == "string" and bytes or nil
end

local function markerInfo()
  local text = readFile(MARKER)
  if not text then return nil end
  local format, count, variants, hash = text:match("^(%S+)%s+(%d+)%s+(%d+)%s*(%S*)")
  if not format then return nil end
  return {
    format = format,
    count = tonumber(count),
    variants = tonumber(variants),
    md5 = hash ~= "" and hash or nil,
  }
end

local function dexFor(species, supplied)
  local dex = tonumber(supplied)
  if dex then return math.floor(dex) end
  if not species then return nil end
  local cfg = (ELIGIBLE and ELIGIBLE[species])
    or (GROUND_ELIGIBLE and GROUND_ELIGIBLE[species])
  if cfg and tonumber(cfg.dex) then return math.floor(tonumber(cfg.dex)) end
  local pokemon = Game and Game.data and Game.data.pokemon or nil
  local def = pokemon and pokemon[species] or nil
  return def and tonumber(def.dex) and math.floor(tonumber(def.dex)) or nil
end

local function pathForDex(dex, variant)
  if not dex or dex < 1 or dex > 251 then return nil end
  local root = variant == "shiny" and SHINY_DIR or NORMAL_DIR
  return string.format("%s/%03d.dsm", root, dex)
end

local function supportsSpecies(species, suppliedDex)
  local dex = dexFor(species, suppliedDex)
  if not dex or dex < 1 or dex > 251 then return false end
  return fileExists(pathForDex(dex, "normal"))
end

local function isShiny(mon)
  local dvs = mon and mon.dvs
  if type(dvs) ~= "table" then return false end
  local attack = tonumber(dvs.attack)
  local okAttack = attack == 2 or attack == 3 or attack == 6 or attack == 7
    or attack == 10 or attack == 11 or attack == 14 or attack == 15
  return okAttack and tonumber(dvs.defense) == 10
    and tonumber(dvs.speed) == 10 and tonumber(dvs.special) == 10
end

local function findPartyMon(species)
  local party = Game and Game.save and Game.save.party or nil
  if type(party) ~= "table" then return nil end
  for _, mon in ipairs(party) do
    if type(mon) == "table" and mon.species == species then return mon end
  end
  return nil
end

local function currentMount()
  if flight and flight.active and flight.species then
    return "flight", flight.species, flight.mon
  end
  if ground and ground.active and ground.species then
    return "ground", ground.species, ground.mon
  end
  local ex = mod.exports or {}
  if type(ex.isWaterRiding) == "function" and type(ex.waterMountSpecies) == "function" then
    local okActive, active = pcall(ex.isWaterRiding)
    if okActive and active == true then
      local okSpecies, species = pcall(ex.waterMountSpecies)
      if okSpecies and species then return "water", species, findPartyMon(species) end
    end
  end
  return nil
end

local function rendererSelected()
  if voxelLevel() <= 0 then return false end
  local rendering = mod.exports and mod.exports.flightRendering or nil
  if not (rendering and type(rendering.usesStadium) == "function") then return false end
  local ok, value = pcall(rendering.usesStadium)
  return ok and value == true
end

-- -------------------------------------------------------------------------
-- DSM4 binary reader. Positions/rotations are little-endian; rotations use
-- N64 binary angles (32768 == pi), and bone scale uses signed 16.16 fixed.
-- -------------------------------------------------------------------------
local function byteAt(s, p)
  local v = string.byte(s, p)
  if v == nil then error("unexpected end of DSM4 pack", 0) end
  return v, p + 1
end

local function u16(s, p)
  local a, b = string.byte(s, p, p + 1)
  if b == nil then error("unexpected end of DSM4 pack", 0) end
  return a + b * 256, p + 2
end

local function i16(s, p)
  local v
  v, p = u16(s, p)
  if v >= 32768 then v = v - 65536 end
  return v, p
end

local function u32(s, p)
  local a, b, c, d = string.byte(s, p, p + 3)
  if d == nil then error("unexpected end of DSM4 pack", 0) end
  return a + b * 256 + c * 65536 + d * 16777216, p + 4
end

local function i32(s, p)
  local v
  v, p = u32(s, p)
  if v >= 2147483648 then v = v - 4294967296 end
  return v, p
end

local function f32(s, p)
  local b1, b2, b3, b4 = string.byte(s, p, p + 3)
  if b4 == nil then error("unexpected end of DSM4 pack", 0) end
  local sign = 1
  if b4 >= 128 then sign, b4 = -1, b4 - 128 end
  local exponent = b4 * 2 + math.floor(b3 / 128)
  local mantissa = (b3 % 128) * 65536 + b2 * 256 + b1
  if exponent == 255 then
    return mantissa == 0 and sign * math.huge or 0 / 0, p + 4
  end
  if exponent == 0 then return sign * mantissa * 2 ^ -149, p + 4 end
  return sign * (1 + mantissa / 8388608) * 2 ^ (exponent - 127), p + 4
end

local function fixed(s, p)
  local v
  v, p = i32(s, p)
  return v / 65536, p
end

local COMPONENT_READERS = { i16, i16, i16, i16, i16, i16,
                            fixed, fixed, fixed }
local COMPONENT_BYTES = { 2, 2, 2, 2, 2, 2, 4, 4, 4 }

local function skipTracks(bytes, p, bones, frames)
  for _ = 1, bones do
    local present
    present, p = byteAt(bytes, p)
    if present ~= 0 then
      for component = 1, 9 do
        local kind
        kind, p = byteAt(bytes, p)
        p = p + COMPONENT_BYTES[component] * (kind == 0 and 1 or frames)
        if p > #bytes + 1 then error("animation tracks exceed DSM4 pack", 0) end
      end
    end
  end
  return p
end

local function parsePack(bytes)
  if type(bytes) ~= "string" or bytes:sub(1, 4) ~= PACK_MAGIC then
    error("unsupported Stadium pack (expected DSM4)", 0)
  end
  local p, model = 5, { bytes = bytes }
  model.species, p = u16(bytes, p)
  model.boneCount, p = u16(bytes, p)
  model.primCount, p = u16(bytes, p)
  model.texCount, p = u16(bytes, p)
  model.animCount, p = u16(bytes, p)
  model.auxCount, p = u16(bytes, p)
  model.attachmentCount, p = u16(bytes, p)
  model.rootScale, p = f32(bytes, p)
  local static
  static, p = byteAt(bytes, p)
  model.staticPose = static ~= 0
  model.height, p = f32(bytes, p)
  model.floor, p = f32(bytes, p)
  model.radius, p = f32(bytes, p)

  -- Move-specific battle slots are not needed by an overworld mount, but they
  -- are part of the pack header and must be traversed before context slots.
  for _ = 1, MOVE_SLOTS do local _v; _v, p = u16(bytes, p) end
  for _ = 1, MOVE_SLOTS do local _v; _v, p = i16(bytes, p) end
  model.ctx = {}
  for i = 1, CONTEXT_SLOTS do model.ctx[i], p = u16(bytes, p) end

  model.parent, model.restT, model.restR, model.restS = {}, {}, {}, {}
  for bone = 1, model.boneCount do
    local parent
    parent, p = i16(bytes, p)
    model.parent[bone] = parent + 1
    local o = (bone - 1) * 3
    model.restT[o + 1], p = i16(bytes, p)
    model.restT[o + 2], p = i16(bytes, p)
    model.restT[o + 3], p = i16(bytes, p)
    model.restR[o + 1], p = i16(bytes, p)
    model.restR[o + 2], p = i16(bytes, p)
    model.restR[o + 3], p = i16(bytes, p)
    model.restS[o + 1], p = fixed(bytes, p)
    model.restS[o + 2], p = fixed(bytes, p)
    model.restS[o + 3], p = fixed(bytes, p)
  end

  model.attachments = {}
  for i = 1, model.attachmentCount do
    local bone, tag
    bone, p = i16(bytes, p)
    tag, p = i16(bytes, p)
    model.attachments[i] = { bone = bone + 1, tag = tag }
  end

  model.prims = {}
  for i = 1, model.primCount do
    local prim = {}
    prim.tex, p = u16(bytes, p); prim.tex = prim.tex + 1
    local cull, additive
    cull, p = byteAt(bytes, p)
    additive, p = byteAt(bytes, p)
    prim.cull, prim.additive = cull ~= 0, additive ~= 0
    prim.texAnim, p = i16(bytes, p)
    local mapCount
    mapCount, p = byteAt(bytes, p)
    if mapCount > 0 then
      prim.texMap = {}
      for _ = 1, mapCount do
        local key, texture
        key, p = byteAt(bytes, p)
        texture, p = u16(bytes, p)
        prim.texMap[key] = texture + 1
      end
    end
    local fxCount
    fxCount, p = u16(bytes, p)
    for _ = 1, fxCount do local _v; _v, p = u16(bytes, p) end
    prim.vertCount, p = u16(bytes, p)
    prim.indexCount, p = u16(bytes, p)
    prim.px, prim.py, prim.pz = {}, {}, {}
    prim.u, prim.v = {}, {}
    prim.nx, prim.ny, prim.nz = {}, {}, {}
    prim.bone = {}
    for vertex = 1, prim.vertCount do
      prim.px[vertex], p = i16(bytes, p)
      prim.py[vertex], p = i16(bytes, p)
      prim.pz[vertex], p = i16(bytes, p)
      local uu, vv
      uu, p = i16(bytes, p); vv, p = i16(bytes, p)
      prim.u[vertex], prim.v[vertex] = uu / 512, vv / 512
      local nx, ny, nz
      nx, p = byteAt(bytes, p); ny, p = byteAt(bytes, p); nz, p = byteAt(bytes, p)
      if nx >= 128 then nx = nx - 256 end
      if ny >= 128 then ny = ny - 256 end
      if nz >= 128 then nz = nz - 256 end
      prim.nx[vertex], prim.ny[vertex], prim.nz[vertex] = nx / 127, ny / 127, nz / 127
      local bone
      bone, p = byteAt(bytes, p)
      prim.bone[vertex] = bone + 1
    end
    prim.indices = {}
    for index = 1, prim.indexCount do
      prim.indices[index], p = u16(bytes, p)
      prim.indices[index] = prim.indices[index] + 1
    end
    model.prims[i] = prim
  end

  model.textures = {}
  for i = 1, model.texCount do
    local w, h, length
    w, p = u16(bytes, p); h, p = u16(bytes, p); length, p = u32(bytes, p)
    if length < 0 or p + length - 1 > #bytes then error("invalid DSM4 texture payload", 0) end
    model.textures[i] = { w = w, h = h, rgba = bytes:sub(p, p + length - 1) }
    p = p + length
  end

  model.anims = {}
  for i = 1, model.animCount do
    local nameLen
    nameLen, p = byteAt(bytes, p)
    local name = bytes:sub(p, p + nameLen - 1)
    p = p + nameLen
    local frames, loopStart, aux
    frames, p = u16(bytes, p); loopStart, p = u16(bytes, p); aux, p = i16(bytes, p)
    local record = {
      name = name,
      frames = math.max(1, frames),
      loopStart = loopStart,
      aux = aux >= 0 and (aux + 1) or nil,
      offset = p,
    }
    model.anims[i] = record
    p = skipTracks(bytes, p, model.boneCount, record.frames)
  end

  model.auxAnims = {}
  for i = 1, model.auxCount do
    local frames, loopStart, channelCount
    frames, p = u16(bytes, p); loopStart, p = u16(bytes, p)
    channelCount, p = u16(bytes, p)
    local aux = { frames = frames, loopStart = loopStart, channels = {} }
    for channel = 1, channelCount do
      local count
      count, p = u16(bytes, p)
      local stream = {}
      for index = 1, count do stream[index], p = u16(bytes, p) end
      aux.channels[channel] = stream
    end
    model.auxAnims[i] = aux
  end
  return model
end

local function tracksFor(model, animIndex)
  local record = model and model.anims and model.anims[animIndex]
  if not record then return nil end
  if record.tracks then return record.tracks end
  local p, out = record.offset, {}
  for bone = 1, model.boneCount do
    local present
    present, p = byteAt(model.bytes, p)
    if present ~= 0 then
      local components = {}
      for component = 1, 9 do
        local kind
        kind, p = byteAt(model.bytes, p)
        local read = COMPONENT_READERS[component]
        if kind == 0 then
          components[component], p = read(model.bytes, p)
        else
          local values = {}
          for frame = 1, record.frames do values[frame], p = read(model.bytes, p) end
          components[component] = values
        end
      end
      out[bone] = components
    end
  end
  record.tracks = out
  return out
end

local function sample(component, frameIndex)
  if type(component) == "number" then return component end
  if type(component) ~= "table" then return 0 end
  return component[frameIndex + 1] or component[#component] or 0
end

local function idleAnimation(model)
  local raw = model and model.ctx and model.ctx[CONTEXT_IDLE]
  if raw and raw ~= NONE16 and model.anims[raw + 1] then return raw + 1 end
  return model and model.anims and model.anims[1] and 1 or nil
end

local function animationFrame(record, seconds)
  if not record or record.frames <= 1 then return 0 end
  local frame = math.floor(math.max(0, seconds or 0) * MODEL_FPS)
  if frame < record.frames then return frame end
  local loopStart = tonumber(record.loopStart) or 0
  if loopStart < 0 or loopStart >= record.frames then loopStart = 0 end
  return loopStart + (frame - loopStart) % math.max(1, record.frames - loopStart)
end

-- -------------------------------------------------------------------------
-- Runtime skeleton + meshes.
-- -------------------------------------------------------------------------
local function mul3(a, b)
  return {
    a[1]*b[1]+a[2]*b[4]+a[3]*b[7], a[1]*b[2]+a[2]*b[5]+a[3]*b[8], a[1]*b[3]+a[2]*b[6]+a[3]*b[9],
    a[4]*b[1]+a[5]*b[4]+a[6]*b[7], a[4]*b[2]+a[5]*b[5]+a[6]*b[8], a[4]*b[3]+a[5]*b[6]+a[6]*b[9],
    a[7]*b[1]+a[8]*b[4]+a[9]*b[7], a[7]*b[2]+a[8]*b[5]+a[9]*b[8], a[7]*b[3]+a[8]*b[6]+a[9]*b[9],
  }
end

local function rotation3(rx, ry, rz)
  local ax, ay, az = rx * math.pi / 32768, ry * math.pi / 32768, rz * math.pi / 32768
  local sx, cx, sy, cy, sz, cz = math.sin(ax), math.cos(ax), math.sin(ay), math.cos(ay), math.sin(az), math.cos(az)
  local mx = { 1,0,0, 0,cx,-sx, 0,sx,cx }
  local my = { cy,0,sy, 0,1,0, -sy,0,cy }
  local mz = { cz,-sz,0, sz,cz,0, 0,0,1 }
  return mul3(mul3(mx, my), mz)
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
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
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

local function createRuntime(model, species, dex, variant, provider)
  if not (provider and provider.Voxel3D and love and love.graphics and love.graphics.newMesh) then return nil end
  local runtime = {
    model = model, species = species, dex = dex, variant = variant,
    parts = {}, pivot = {}, drawM = {}, accX = {}, accY = {}, accZ = {},
    time = 0, frame = -1, facing = "down", anim = idleAnimation(model),
  }
  for index, prim in ipairs(model.prims or {}) do
    local rows = {}
    for vertex = 1, prim.vertCount do
      rows[vertex] = { 0, 0, 0, prim.u[vertex], prim.v[vertex], 1 }
    end
    local ok, mesh = pcall(love.graphics.newMesh, provider.Voxel3D.FORMAT,
      rows, "triangles", "dynamic")
    if not ok or not mesh then
      for _, part in ipairs(runtime.parts) do
        if part.mesh and part.mesh.release then pcall(part.mesh.release, part.mesh) end
      end
      return nil
    end
    pcall(mesh.setVertexMap, mesh, prim.indices)
    runtime.parts[index] = { mesh = mesh, rows = rows, prim = prim }
  end
  if not runtime.parts[1] then return nil end
  runtime.sentinel = runtime.parts[1].mesh
  ownerByMesh[runtime.sentinel] = runtime
  return runtime
end

local function poseRuntime(runtime, provider)
  local model = runtime.model
  local anim = runtime.anim
  local record = anim and model.anims[anim] or nil
  local frame = animationFrame(record, runtime.time)
  if runtime.frame == frame and runtime.posedFacing == runtime.facing then return true end
  runtime.frame, runtime.posedFacing = frame, runtime.facing
  local tracks = anim and tracksFor(model, anim) or nil

  for bone = 1, model.boneCount do
    local o = (bone - 1) * 3
    local tx, ty, tz = model.restT[o+1], model.restT[o+2], model.restT[o+3]
    local rx, ry, rz = model.restR[o+1], model.restR[o+2], model.restR[o+3]
    local sx, sy, sz = model.restS[o+1], model.restS[o+2], model.restS[o+3]
    local c = tracks and tracks[bone]
    if c then
      tx, ty, tz = sample(c[1], frame), sample(c[2], frame), sample(c[3], frame)
      rx, ry, rz = sample(c[4], frame), sample(c[5], frame), sample(c[6], frame)
      sx, sy, sz = sample(c[7], frame), sample(c[8], frame), sample(c[9], frame)
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
    local ax, ay, az = psx * sx, psy * sy, psz * sz
    runtime.accX[bone], runtime.accY[bone], runtime.accZ[bone] = ax, ay, az
    runtime.drawM[bone] = {
      pivot[1]*ax,pivot[2]*ay,pivot[3]*az,pivot[4],
      pivot[5]*ax,pivot[6]*ay,pivot[7]*az,pivot[8],
      pivot[9]*ax,pivot[10]*ay,pivot[11]*az,pivot[12],
    }
  end

  local yaw = faceYaw(runtime.facing)
  local cy, sy = math.cos(yaw), math.sin(yaw)
  for _, part in ipairs(runtime.parts) do
    local prim, rows = part.prim, part.rows
    for vertex = 1, prim.vertCount do
      local bone = prim.bone[vertex]
      local d, p = runtime.drawM[bone], runtime.pivot[bone]
      if d and p then
        local x, y, z = prim.px[vertex], prim.py[vertex], prim.pz[vertex]
        local row = rows[vertex]
        row[1] = d[1]*x+d[2]*y+d[3]*z+d[4]
        row[2] = d[5]*x+d[6]*y+d[7]*z+d[8]
        row[3] = d[9]*x+d[10]*y+d[11]*z+d[12]
        local nx, ny, nz = prim.nx[vertex], prim.ny[vertex], prim.nz[vertex]
        local wx = p[1]*nx+p[2]*ny+p[3]*nz
        local wy = p[5]*nx+p[6]*ny+p[7]*nz
        local wz = p[9]*nx+p[10]*ny+p[11]*nz
        local worldX, worldZ = cy*wx+sy*wz, cy*wz-sy*wx
        local shade = 0.7725 + 0.06*worldX + 0.225*wy + 0.11*worldZ
        row[6] = math.max(0.45, math.min(1.05, shade))
      end
    end
    pcall(part.mesh.setVertices, part.mesh, rows)

    local textureIndex = prim.tex
    local auxIndex = record and record.aux or nil
    local aux = auxIndex and model.auxAnims[auxIndex] or nil
    if aux and prim.texAnim and prim.texAnim >= 0 and prim.texMap then
      local stream = aux.channels and aux.channels[prim.texAnim + 1] or nil
      if type(stream) == "table" and #stream > 0 then
        local at = math.min(#stream, frame + 1)
        local mapped = prim.texMap[stream[at]]
        if mapped then textureIndex = mapped end
      end
    end
    part.texture = makeTexture(model.textures[textureIndex])
  end
  return true
end

local function providerModules()
  local Voxel3D = dramaticModule("Voxel3D")
  local SpriteBillboards = dramaticModule("SpriteBillboards")
  local ShadowMap = dramaticModule("ShadowMap")
  local Mat4 = dramaticModule("Mat4")
  if not (Voxel3D and SpriteBillboards and ShadowMap and Mat4) then return nil end
  return { Voxel3D = Voxel3D, SpriteBillboards = SpriteBillboards,
           ShadowMap = ShadowMap, Mat4 = Mat4 }
end

local function runtimeKey(dex, variant)
  return tostring(dex) .. ":" .. tostring(variant)
end

local function ensureRuntime(species, mon)
  local dex = dexFor(species)
  if not dex or not supportsSpecies(species, dex) then return nil end
  local variant = isShiny(mon) and "shiny" or "normal"
  if variant == "shiny" and not fileExists(pathForDex(dex, "shiny")) then variant = "normal" end
  local key = runtimeKey(dex, variant)
  if runtimeCache[key] ~= nil then return runtimeCache[key] or nil end
  if failedRuntime[key] then return nil end
  local provider = providerModules()
  if not provider then return nil end
  local path = pathForDex(dex, variant)
  local bytes = readFile(path)
  if not bytes then return nil end
  local ok, model = pcall(parsePack, bytes)
  if not ok or not model then
    failedRuntime[key] = true
    warnOnce("parse:" .. key, "Stadium 2 pack %s could not be read: %s",
      tostring(path), tostring(model))
    return nil
  end
  local runtime = createRuntime(model, species, dex, variant, provider)
  if not runtime then
    failedRuntime[key] = true
    warnOnce("mesh:" .. key, "Stadium 2 model %03d could not create GPU meshes", dex)
    return nil
  end
  runtimeCache[key] = runtime
  poseRuntime(runtime, provider)
  log("Stadium 2 native model ready: %s #%03d (%s, bones=%d, prims=%d, anims=%d)",
    tostring(species), dex, variant, model.boneCount or 0,
    model.primCount or 0, model.animCount or 0)
  return runtime
end

local function releaseRuntime(runtime)
  if not runtime then return end
  for _, part in ipairs(runtime.parts or {}) do
    if part.mesh and part.mesh.release then pcall(part.mesh.release, part.mesh) end
  end
  for _, slot in ipairs(runtime.model and runtime.model.textures or {}) do
    if slot.image and slot.image.release then pcall(slot.image.release, slot.image) end
    slot.image = nil
  end
end

local function clearRuntimes()
  for _, runtime in pairs(runtimeCache) do if runtime then releaseRuntime(runtime) end end
  runtimeCache, failedRuntime = {}, {}
  ownerByMesh = setmetatable({}, { __mode = "k" })
  runtimeByDef = setmetatable({}, { __mode = "k" })
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

local function modelMatrix(runtime, provider)
  local ow, player = Game and Game.overworld or nil, Game and Game.overworld and Game.overworld.player or nil
  if not (ow and player and runtime and runtime.model) then return nil end
  local kind, species = currentMount()
  if not kind or species ~= runtime.species then return nil end
  local baseY
  if kind == "flight" then
    baseY = tonumber(flight.altitude) or 0
  else
    baseY = terrainGroundHeight(ow.map, player.cellX, player.cellY)
  end
  local desiredHeight = 16 * mountScale(species)
  local model = runtime.model
  local root = tonumber(model.rootScale) or 1
  if root <= 0 then root = 1 end
  local rawHeight = tonumber(model.height) or 1
  if rawHeight <= 0 then rawHeight = 1 end
  local scale = root * desiredHeight / rawHeight
  local floor = tonumber(model.floor) or 0
  local rawFloor = floor / root
  local yaw = faceYaw(player.facing)
  local Mat4 = provider.Mat4
  return Mat4.mul(
    Mat4.mul(
      Mat4.mul(Mat4.translate(player.px + 8, baseY, player.py + 8), Mat4.rotateY(yaw)),
      Mat4.scale(scale, scale, scale)),
    Mat4.translate(0, -rawFloor, 0))
end

local specialSprites = {}
local function stadiumSprite(baseSprite, runtime)
  if not (baseSprite and baseSprite.def and runtime) then return nil end
  local key = tostring(runtime.dex) .. ":" .. tostring(runtime.variant)
    .. ":" .. tostring(baseSprite.def.image)
  local cached = specialSprites[key]
  if cached then
    runtimeByDef[cached.def] = runtime
    return cached
  end
  local def = {}
  for k, v in pairs(baseSprite.def) do def[k] = v end
  def.id = "DSR_STADIUM2_" .. tostring(runtime.species)
  def.frames = 6
  def.walker = true
  def.trueColor = true
  def.dramaticSkyRideMountSpecies = runtime.species
  def.dramaticSkyRideStadiumNative = true
  local sprite = SpriteRenderer.new(def, "dsr_stadium2:" .. tostring(runtime.species))
  sprite.image = baseSprite.image
  specialSprites[key] = sprite
  runtimeByDef[def] = runtime
  return sprite
end

local provider = providerModules()
if provider then
  local billboards, voxel, shadow = provider.SpriteBillboards, provider.Voxel3D, provider.ShadowMap

  if not billboards.dramaticSkyRideStadium2Hook then
    local rawMesh, rawShadowQuad = billboards.mesh, billboards.shadowQuad
    billboards.mesh = function(def, frame)
      if def and def.dramaticSkyRideStadiumNative then
        local runtime = runtimeByDef[def]
        if runtime and runtime.sentinel then return runtime.sentinel end
      end
      return rawMesh(def, frame)
    end
    billboards.shadowQuad = function(def, frame)
      if def and def.dramaticSkyRideStadiumNative then
        local runtime = runtimeByDef[def]
        if runtime and runtime.sentinel then return runtime.sentinel end
      end
      return rawShadowQuad(def, frame)
    end
    billboards.dramaticSkyRideStadium2Hook = true
  end

  if not voxel.dramaticSkyRideStadium2Hook and type(voxel.draw) == "function" then
    local rawDraw = voxel.draw
    voxel.draw = function(mesh, texture, matrix, pull, sunModel)
      local runtime = ownerByMesh[mesh]
      if not runtime then return rawDraw(mesh, texture, matrix, pull, sunModel) end
      local activeProvider = providerModules() or provider
      local custom = modelMatrix(runtime, activeProvider)
      if not custom then return rawDraw(mesh, texture, matrix, pull, sunModel) end
      if voxel.seams then voxel.seams(false) end
      if voxel.glass then voxel.glass(false) end
      local additive = {}
      for _, part in ipairs(runtime.parts) do
        if part.prim.additive then
          additive[#additive + 1] = part
        elseif part.texture then
          rawDraw(part.mesh, part.texture, custom, 0, custom)
        end
      end
      if #additive > 0 and voxel.blend then voxel.blend("add") end
      for _, part in ipairs(additive) do
        if part.texture then rawDraw(part.mesh, part.texture, custom, 0, custom) end
      end
      if #additive > 0 and voxel.blend then voxel.blend(nil) end
      if voxel.glass then voxel.glass(true) end
      if voxel.seams then voxel.seams(true) end
      return true
    end
    voxel.dramaticSkyRideStadium2Hook = true
  end

  if not shadow.dramaticSkyRideStadium2Hook and type(shadow.draw) == "function" then
    local rawShadowDraw = shadow.draw
    shadow.draw = function(mesh, texture, matrix)
      local runtime = ownerByMesh[mesh]
      if not runtime then return rawShadowDraw(mesh, texture, matrix) end
      local activeProvider = providerModules() or provider
      local custom = modelMatrix(runtime, activeProvider)
      if not custom then return rawShadowDraw(mesh, texture, matrix) end
      for _, part in ipairs(runtime.parts) do
        if part.texture and not part.prim.additive then
          rawShadowDraw(part.mesh, part.texture, custom)
        end
      end
      return true
    end
    shadow.dramaticSkyRideStadium2Hook = true
  end
end

-- Late pose wrapper: all existing Wilds/PokePC/PokeMMO/size logic resolves
-- first. Only the final visual returned for the mounted PLAYER in an active
-- voxel Stadium mode becomes the sentinel sprite consumed by the hooks above.
local previousStadiumPose = Player.pose
function Player:pose(...)
  local sprite, px, py, facing, phase, flip, hopping = previousStadiumPose(self, ...)
  local ow = Game and Game.overworld or nil
  if not (ow and ow.player == self and rendererSelected()) then
    return sprite, px, py, facing, phase, flip, hopping
  end
  local kind, species, mon = currentMount()
  if not kind or not species then return sprite, px, py, facing, phase, flip, hopping end
  local runtime = ensureRuntime(species, mon)
  if not runtime then return sprite, px, py, facing, phase, flip, hopping end
  runtime.facing = facing or self.facing or "down"
  local replacement = stadiumSprite(sprite, runtime)
  return replacement or sprite, px, py, facing, phase, flip, hopping
end

-- Drive the source idle loop once per game update, not once per render pass.
-- Battle Art may ask for the same geometry from the sun, reflection and camera
-- in one frame; all three therefore see exactly one common skinned pose.
local previousStadiumUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousStadiumUpdate(self, dt, ...)
  if Game.overworld == self and rendererSelected() then
    local _, species, mon = currentMount()
    if species then
      local runtime = ensureRuntime(species, mon)
      if runtime then
        runtime.time = (runtime.time or 0) + math.max(0, tonumber(dt) or 0)
        runtime.facing = self.player and self.player.facing or runtime.facing
        local p = providerModules()
        if p then
          local ok, err = pcall(poseRuntime, runtime, p)
          if not ok then warnOnce("pose:" .. tostring(runtime.dex),
            "Stadium 2 animation failed for #%03d: %s", runtime.dex, tostring(err)) end
        end
      end
    end
  end
  return result
end

if Assets and Assets.register then Assets.register(clearRuntimes) end

mod.events:on("mod.options_changed", function(payload)
  if not payload then return end
  if payload.mod == mod.id then
    local key = tostring(payload.key or "")
    if key == "pokedex_mount_sizes" or key:match("^mount_size_")
        or key == "flight_mount_renderer" then
      for _, runtime in pairs(runtimeCache) do
        if runtime then runtime.frame = -1 end
      end
    end
  end
end)

mod.exports.stadium3DNative = {
  api = 1,
  installed = function()
    local marker = markerInfo()
    return marker ~= nil or fileExists(pathForDex(1, "normal"))
  end,
  supportsSpecies = supportsSpecies,
  hasModel = supportsSpecies,
  modelAvailable = supportsSpecies,
  active = rendererSelected,
  cacheStatus = function()
    local marker = markerInfo()
    return {
      root = CACHE_ROOT,
      marker = marker ~= nil,
      format = marker and marker.format or nil,
      expectedFormat = EXPECTED_FORMAT,
      count = marker and marker.count or 0,
      variants = marker and marker.variants or 0,
      md5 = marker and marker.md5 or nil,
    }
  end,
  modelInfo = function(species)
    local dex = dexFor(species)
    local runtime = dex and ensureRuntime(species, findPartyMon(species)) or nil
    local model = runtime and runtime.model or nil
    if not model then return nil end
    return {
      species = species, dex = dex, variant = runtime.variant,
      height = model.height, floor = model.floor, radius = model.radius,
      bones = model.boneCount, primitives = model.primCount,
      textures = model.texCount, animations = model.animCount,
      idleAnimation = runtime.anim,
    }
  end,
  clearCache = clearRuntimes,
}

local marker = markerInfo()
if marker then
  log("Native Stadium 2 renderer loaded (cache %s, count=%s, variants=%s)",
    tostring(marker.format), tostring(marker.count), tostring(marker.variants))
else
  log("Native Stadium 2 renderer loaded (no generated Stadium 2 cache detected yet)")
end
end)();
