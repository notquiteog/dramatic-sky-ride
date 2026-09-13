(function()
-- -------------------------------------------------------------------------
-- Recover generated Stadium effect flipbooks from DSM4 packs.
--
-- main_41's initial proof-of-concept deliberately skipped the fxFrames array
-- while advancing through each primitive. That kept the binary cursor correct
-- but meant generated fire/gas primitives were stuck on their first texture.
-- Crystal 251 writes those frame indices into DSM4 exactly like StadiumBuild;
-- keep the core parser untouched and decorate its model with a strict second
-- pass so this remains easy to remove/review while the renderer is experimental.
-- -------------------------------------------------------------------------

local MOVE_SLOTS = 165
local CONTEXT_SLOTS = 20
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

local function need(bytes, p, n)
  if type(bytes) ~= "string" or p < 1 or n < 0 or p + n - 1 > #bytes then
    error("DSM4 effect-frame scan exceeded pack bounds", 0)
  end
end

local function u8(bytes, p)
  need(bytes, p, 1)
  return string.byte(bytes, p), p + 1
end

local function u16(bytes, p)
  need(bytes, p, 2)
  local a, b = string.byte(bytes, p, p + 1)
  return a + b * 256, p + 2
end

local function skip(bytes, p, n)
  need(bytes, p, n)
  return p + n
end

local function recoverFxFrames(bytes, model)
  if type(model) ~= "table" or type(model.prims) ~= "table" then
    return false, "model_missing"
  end
  if type(bytes) ~= "string" or bytes:sub(1, 4) ~= "DSM4" then
    return false, "pack_magic"
  end

  local p = 5
  local species, bones, prims, textures, attachments
  species, p = u16(bytes, p)
  bones, p = u16(bytes, p)
  prims, p = u16(bytes, p)
  textures, p = u16(bytes, p)
  p = skip(bytes, p, 4) -- animation + aux counts
  attachments, p = u16(bytes, p)

  if species ~= tonumber(model.species) or bones ~= tonumber(model.boneCount)
      or prims ~= tonumber(model.primCount) or textures ~= tonumber(model.texCount)
      or attachments ~= tonumber(model.attachmentCount) then
    return false, "header_mismatch"
  end

  -- rootScale + staticPose + height/floor/radius
  p = skip(bytes, p, 4 + 1 + 12)
  -- move animation table, move aux table, context slots
  p = skip(bytes, p, MOVE_SLOTS * 2 + MOVE_SLOTS * 2 + CONTEXT_SLOTS * 2)
  -- parent + T(3*i16) + R(3*i16) + S(3*i32)
  p = skip(bytes, p, bones * 26)
  -- signed bone/tag pairs
  p = skip(bytes, p, attachments * 4)

  local effectParts, effectFrames = 0, 0
  for index = 1, prims do
    local prim = model.prims[index]
    if type(prim) ~= "table" then return false, "primitive_mismatch" end

    -- tex u16, cull u8, blend u8, texAnim i16
    p = skip(bytes, p, 6)
    local mapN
    mapN, p = u8(bytes, p)
    p = skip(bytes, p, mapN * 3) -- key u8 + tex u16

    local fxN
    fxN, p = u16(bytes, p)
    if fxN > 0 then
      local frames = {}
      for frame = 1, fxN do
        local texture
        texture, p = u16(bytes, p)
        texture = texture + 1 -- pack is 0-based; Lua model is 1-based
        if texture < 1 or texture > textures then
          return false, "effect_texture_range"
        end
        frames[frame] = texture
      end
      prim.fxFrames = frames
      effectParts = effectParts + 1
      effectFrames = effectFrames + #frames
    else
      prim.fxFrames = nil
    end

    local nv, ni
    nv, p = u16(bytes, p)
    ni, p = u16(bytes, p)
    if nv ~= tonumber(prim.vertCount) or ni ~= tonumber(prim.indexCount) then
      return false, "primitive_size_mismatch"
    end
    -- xyz i16 + uv i16/i16 + normal i8/i8/i8 + bone u8 = 14 bytes
    p = skip(bytes, p, nv * 14 + ni * 2)
  end

  model._dsrFxParts = effectParts
  model._dsrFxFrames = effectFrames
  model._dsrFxRecovered = true
  return true
end

local _, ensureWrapper = findUpvalue(Player and Player.pose, "ensureRuntime")
local _, rawEnsureRuntime = findUpvalue(ensureWrapper, "rawEnsureRuntime")
if type(rawEnsureRuntime) ~= "function" then rawEnsureRuntime = ensureWrapper end
local parseIndex, rawParsePack = findUpvalue(rawEnsureRuntime, "parsePack")

local parsePatched = false
if type(rawParsePack) == "function" and parseIndex and debug and debug.setupvalue then
  local function parsePackWithEffects(bytes)
    local model = rawParsePack(bytes)
    if model then
      local ok, recovered, reason = pcall(recoverFxFrames, bytes, model)
      if not ok then
        model._dsrFxRecoveryFailed = true
        warnOnce("scan:" .. tostring(model.species),
          "Stadium 2 effect-frame scan failed for #%s: %s",
          tostring(model.species), tostring(recovered))
      elseif recovered ~= true then
        model._dsrFxRecoveryFailed = true
        warnOnce("scan:" .. tostring(model.species) .. ":" .. tostring(reason),
          "Stadium 2 effect-frame scan declined #%s: %s",
          tostring(model.species), tostring(reason))
      end
    end
    return model
  end
  parsePatched = pcall(debug.setupvalue, rawEnsureRuntime, parseIndex,
    parsePackWithEffects)
end

mod.exports.stadium3DEffects = {
  api = 1,
  parsePatched = parsePatched,
  fps = 30,
  info = function(species)
    local native = mod.exports and mod.exports.stadium3DNative or nil
    local modelInfo = native and native.modelInfo
    if type(modelInfo) ~= "function" then return nil end
    -- modelInfo intentionally exposes only compact public data; the diagnostic
    -- counters are therefore exported through the loaded runtime below when a
    -- caller has already caused the species to be built.
    local ok, info = pcall(modelInfo, species)
    return ok and info or nil
  end,
}

if parsePatched then
  log("Stadium 2 effect-frame recovery loaded")
else
  warnOnce("install", "Stadium 2 effect-frame recovery could not patch the DSM4 parser")
end
end)();
