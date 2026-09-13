;(function()
-- -------------------------------------------------------------------------
-- Optional OTF Player Switcher compatibility.
--
-- on1san/otf-player-switcher changes SPRITE_RED.image at runtime. DSR normally
-- caches its cropped rider sheet by sprite id, so two characters sharing the
-- SPRITE_RED id could otherwise reuse the same cached rider. Keep this layer
-- capability-gated: when OTF is absent, every call falls through to the exact
-- existing DSR behavior.
-- -------------------------------------------------------------------------
local OTF_MOD_ID = "otf-player-switcher"
local originalBuildRiderSprite = buildRiderSprite
local originalWriteRiderSheet = writeRiderSheet
local pendingRefresh = false
local lastRiderSource = nil

local function otfHandle()
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, OTF_MOD_ID)
  return ok and handle or nil
end

local function otfInstalled()
  return otfHandle() ~= nil
end

local function shortHash(value)
  value = tostring(value or "")
  local hash = 5381
  for i = 1, #value do
    hash = (hash * 33 + value:byte(i)) % 2147483647
  end
  return string.format("%08x", hash)
end

local function currentOtfPlayerImage(player)
  if not otfInstalled() then
    local source = mod.exports._riderSourceSprite(player)
    local def = source and source.def or nil
    return def and def.image or nil
  end

  -- OTF writes the selected overworld character directly into the canonical
  -- SPRITE_RED data entry. Use that as the authoritative mounted-rider source
  -- even if an already-created Player renderer has not refreshed its def yet.
  local sprites = Game and Game.data and Game.data.sprites or nil
  local red = sprites and sprites.SPRITE_RED or nil
  if red and red.image then return red.image end

  local source = mod.exports._riderSourceSprite(player)
  local def = source and source.def or nil
  return def and def.image or nil
end

local function riderSourceFingerprint(player)
  local source = mod.exports._riderSourceSprite(player)
  local def = source and source.def or nil
  local image = currentOtfPlayerImage(player)
  if not image then return nil end
  return tostring(def and def.id or "SPRITE_RED") .. "|" .. tostring(image)
end

-- Give every OTF character a unique runtime rider sheet. The proxy is only
-- used while building the crop; the live player definition is never mutated.
buildRiderSprite = function(player)
  if not otfInstalled() then
    return originalBuildRiderSprite(player)
  end
  local sourceSprite = mod.exports._riderSourceSprite(player)
  if not (sourceSprite and sourceSprite.def) then
    return nil, "player_sprite_missing"
  end

  local sourceDef = sourceSprite.def
  local sourcePath = currentOtfPlayerImage(player)
  if not sourcePath then
    return originalBuildRiderSprite(player)
  end

  local token = shortHash(tostring(sourceDef.id or "SPRITE_RED") .. "|" .. sourcePath)
  local proxyDef = shallowCopy(sourceDef)
  proxyDef.image = sourcePath
  proxyDef.id = tostring(sourceDef.id or "SPRITE_RED") .. "_OTF_" .. token
  local proxyPlayer = { sprite = { def = proxyDef } }

  local path, reason = originalWriteRiderSheet(proxyPlayer)
  if not path then
    -- Match DSR's existing graceful fallback semantics if ImageData encoding
    -- is unavailable on an unusual port.
    return sourceSprite, "uncropped_fallback:" .. tostring(reason)
  end

  local def = shallowCopy(proxyDef)
  def.id = "SKY_RIDE_RIDER_" .. safeAssetName(proxyDef.id)
  def.image = path
  def.frames = 6
  def.walker = true
  local sprite = SpriteRenderer.new(def, "sky_ride_rider:otf:" .. token)
  if sourceSprite.objColors and type(sprite.setObjPalette) == "function" then
    sprite:setObjPalette(sourceSprite.objColors, sourceSprite.objGroup)
  end
  return sprite
end

local function anyMountedState()
  return (flight and flight.active == true)
    or (ground and ground.active == true)
    or (water and water.active == true)
end

local function refreshMountedRider()
  if not otfInstalled() then return false end
  local ow = Game and Game.overworld or nil
  local player = ow and ow.player or nil
  if not (player and anyMountedState()) then return false end

  local rider, reason = buildRiderSprite(player)
  if not rider then
    if mod.log then
      mod.log:warn("OTF rider refresh failed: %s", tostring(reason))
    end
    return false
  end

  local refreshed = false
  if flight.active then
    flight.riderSprite = rider
    if flight.riderEntity then flight.riderEntity.sprite = rider end
    ensureRiderEntity(ow)
    refreshed = true
  end

  if ground.active then
    ground.riderSprite = rider
    if ground.riderEntity then ground.riderEntity.sprite = rider end
    ensureGroundRiderEntity(ow)
    refreshed = true
  end

  if water.active then
    water.riderSprite = rider
    if water.riderEntity then water.riderEntity.sprite = rider end
    ensureWaterRider(ow)
    refreshed = true
  end

  if refreshed then
    lastRiderSource = riderSourceFingerprint(player)
    pendingRefresh = false
  end
  return refreshed
end

-- OTF changes the character before publishing its option change when using
-- PageUp/PageDown. Defer the DSR refresh to the next overworld update so the
-- ordering also stays correct for option-menu changes and future OTF builds.
mod.events:on("mod.options_changed", function(payload)
  if payload and payload.mod == OTF_MOD_ID
      and payload.key == "custom_char_index" then
    pendingRefresh = true
  end
end)

-- Generic source-path detection is deliberately kept in addition to the OTF
-- event. It makes the mounted rider self-heal if OTF changes its event surface
-- while continuing to update SPRITE_RED.image.
local previousOtfCompatUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousOtfCompatUpdate(self, dt, ...)
  if otfInstalled() and Game.overworld == self and self.player then
    local source = riderSourceFingerprint(self.player)
    if anyMountedState() then
      if pendingRefresh or (source and source ~= lastRiderSource) then
        refreshMountedRider()
      end
    else
      lastRiderSource = source
      pendingRefresh = false
    end
  end
  return result
end

-- DSR owns PageUp/PageDown while Flight is active because those keys are held
-- altitude controls. OTF keeps its normal shortcuts while walking, Ground
-- Riding or Surfing. The altitude code polls keyboard state directly, so
-- consuming the keypress here does not interfere with climb/descent input.
local installedKeyGuard = nil
local function installPageKeyGuard()
  local current = Game and Game.keypressed or nil
  if type(current) ~= "function" or current == installedKeyGuard then return end
  local inner = current
  installedKeyGuard = function(self, key, ...)
    if otfInstalled() and flight.active
        and (key == "pageup" or key == "pagedown") then
      return
    end
    return inner(self, key, ...)
  end
  Game.keypressed = installedKeyGuard
end

installPageKeyGuard()
mod.events:on("mods.loaded", function()
  -- Re-assert the outer guard in case another optional mod installed its
  -- keypressed wrapper later in the load sequence.
  installPageKeyGuard()
  if otfInstalled() and mod.log then
    mod.log:info("OTF Player Switcher compatibility active")
  end
end)

mod.exports.otfPlayerSwitcherCompatibility = {
  api = 1,
  modId = OTF_MOD_ID,
  installed = otfInstalled,
  currentPlayerImage = function()
    local ow = Game and Game.overworld or nil
    return currentOtfPlayerImage(ow and ow.player or nil)
  end,
  refreshMountedRider = refreshMountedRider,
}
end)();
