  if math.abs(s) > math.abs(c) then return s > 0 and "right" or "left" end
  return c > 0 and "down" or "up"
end

-- Resolve by the internal species id first, then by Pokédex number. This
-- keeps the addon working with translated data packs or mods that rename
-- species ids while retaining the canonical Gen 1 dex number.
local function mountSpecies(game, mon)
  if not (game and mon) then return nil end
  if ELIGIBLE[mon.species] then return mon.species end
  local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
  local dex = def and tonumber(def.dex)
  return dex and ELIGIBLE_BY_DEX[dex] or nil
end

local flight = {
  active = false,
  phase = "idle", -- idle | takeoff | cruise | landing
  altitude = 0, -- absolute world-space Y, not height above local ground
  requestedAltitude = CRUISE_HEIGHT,
  targetAltitude = CRUISE_HEIGHT,
  safetyAltitude = 0,
  verticalInput = 0,
  hudTimer = 0,
  notice = nil,
  noticeTimer = 0,
  species = nil,
  mon = nil,
  sprite = nil,
  riderSprite = nil,
  riderEntity = nil,
  groundFxSprite = nil,
  groundFxEntity = nil,
  anim = 0,
  boost = 0,
  boostWasHeld = false,
  autoSafetyWasActive = false,
  cameraManualTimer = 0,
  landingX = nil,
  landingY = nil,
  landingKind = nil,
  suspended = nil,
  originMap = nil,
  originX = nil,
  originY = nil,
  originSurf = false,
  originSurfMon = nil,
}

local lastMountIndex = nil
local transitionGuard = false
local pendingFollowerRestore = nil

local function log(fmt, ...)
  if mod.log then mod.log:info(fmt, ...) end
end

local function say(game, text)
  if game and game.stack then
    game.stack:push(TextBox.new(game, Strings(text)))
  end
end

local function revealAltitude(seconds)
  flight.hudTimer = math.max(flight.hudTimer or 0,
                             seconds or ALTITUDE_HUD_SECONDS)
end

local function notifyHud(text, seconds)
  flight.notice = text
  flight.noticeTimer = seconds or NOTICE_HUD_SECONDS
end

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

local function playFlightSound(key)
  if not flightFeedbackEnabled() then return end
  pcall(function() require("src.core.Sound").play(Game.data, key) end)
end

local function rumble(low, high, seconds)
  if not flightFeedbackEnabled() then return end
  local joystickApi = love and love.joystick
  if not (joystickApi and joystickApi.getJoysticks) then return end
  local ok, sticks = pcall(joystickApi.getJoysticks)
  if not ok or type(sticks) ~= "table" then return end
  for _, stick in ipairs(sticks) do
    if stick and stick.setVibration then
      pcall(stick.setVibration, stick, low or 0, high or low or 0,
            seconds or 0.1)
    end
  end
end

local function feedback(kind)
  if kind == "takeoff" then
    playFlightSound("Fly")
    rumble(0.22, 0.38, 0.16)
  elseif kind == "landing" then
    playFlightSound("Ledge")
    rumble(0.28, 0.32, 0.12)
  elseif kind == "boost" then
    playFlightSound("Fly")
    rumble(0.10, 0.22, 0.08)
  elseif kind == "blocked" then
    playFlightSound("Collision")
    rumble(0.12, 0.12, 0.08)
  elseif kind == "safety" then
    rumble(0.06, 0.12, 0.06)
  end
end

local function voxelLevel()
  local state = mod.exports and mod.exports._dramaticProviderState or nil
  local selected = state and state.voxelPipeline
  if selected then
    local ok, level = pcall(Pipelines.level, selected)
    level = ok and tonumber(level) or 0
    if level > 0 then return level end
  end
  -- Compatibility fallback. Current Battle Art and Dramaless both register
  -- "voxel"; keep "st_voxel" for older forks without letting a stale or
  -- incorrect provider hint report OFF while another supported pipeline is on.
  for _, pipelineId in ipairs({ "voxel", "st_voxel" }) do
    if pipelineId ~= selected then
      local ok, level = pcall(Pipelines.level, pipelineId)
      level = ok and tonumber(level) or 0
      if level > 0 then return level end
    end
  end
  return 0
end

local function isFirstPerson()
  return voxelLevel() == FIRST_PERSON_LEVEL
end

local function isThirdPerson()
  return voxelLevel() == THIRD_PERSON_LEVEL
end

local function isFreeCamera()
  local level = voxelLevel()
  return level == FIRST_PERSON_LEVEL or level == THIRD_PERSON_LEVEL
end

-- Every Dramatic Shape voxel camera is supported. OFF has no 3D world in
-- which an airborne height can be represented.
local function isSupportedVoxelMode(level)
  level = tonumber(level) or voxelLevel()
  return level >= VOXEL_FULL_LEVEL and level <= MAX_VOXEL_LEVEL
end

local function unsupportedVoxelMessage(game)
  say(game, "Turn VOXEL on\nbefore taking off.")
end

local function isOutdoor(ow)
  return ow and ow.map and ow.map.def and Map.isOutdoor(ow.map.def)
end

local function healthy(mon)
  return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0
end

local function fileExists(path)
  return love and love.filesystem and love.filesystem.getInfo
         and love.filesystem.getInfo(path) ~= nil
end

local FOLLOWER_IDS = {
  PokePCFollowers_VoxelMerge = true,
  pokepcfollowers = true,
  FOLLOWERS_EX = true,
  followers_ex = true,
}

-- Find the installed sprite pack by manifest id rather than assuming the
-- directory name selected by the launcher/importer.
local function followerPath(species)
  local cfg = ELIGIBLE[species]
  if not cfg then return nil end
  if not (love and love.filesystem and love.filesystem.getDirectoryItems) then
    return nil
  end

  local filename = string.format("follower_%03d.png", cfg.dex)
  local ok, names = pcall(love.filesystem.getDirectoryItems, "mods")
  if ok and type(names) == "table" then
    -- Prefer a recognized follower mod, but verify the actual asset before
    -- accepting it: Followers EX may be installed beside a separate sprite
    -- pack and does not necessarily carry the PNGs itself.
    local fallback = nil
    for _, name in ipairs(names) do
      local root = "mods/" .. name
