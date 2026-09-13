  local value = optionValue("altitude_display", "temporary")
  if value ~= "always" and value ~= "off" then return "temporary" end
  return value
end

local function verticalRate()
  return VERTICAL_RATES[optionValue("vertical_speed", "normal")]
      or VERTICAL_RATES.normal
end

local function landingMarkerEnabled()
  return optionValue("landing_marker", true) == true
end

local function dynamicShadowEnabled()
  return optionValue("dynamic_shadow", true) == true
end

local function mountShortcutEnabled()
  return optionValue("mount_shortcut", true) == true
end

local function flightBoostEnabled()
  return optionValue("flight_boost", true) == true
end

local function cameraFollowEnabled()
  return optionValue("camera_follow", true) == true
end

local function flightFeedbackEnabled()
  return optionValue("flight_feedback", true) == true
end

local function storySafeEnabled()
  return optionValue("story_safe", true) == true
end

-- The mount now flies at a world-space height instead of adding its height
-- to whatever terrain happens to be below it. Mountains, cliff tops and
-- ordinary walls therefore pass underneath without making the rider bob up.
-- A small set of genuinely tall landmark buildings remains an exception.
local TALL_DESTINATIONS = {
  SILPH_CO_1F =          { height = 78, left = 7, right = 7, back = 11, front = 1 },
  POKEMON_TOWER_1F =     { height = 74, left = 6, right = 6, back = 10, front = 1 },
  CELADON_MART_1F =      { height = 66, left = 6, right = 6, back = 9,  front = 1 },
  CELADON_MANSION_1F =   { height = 62, left = 5, right = 5, back = 9,  front = 1 },
  POKEMON_MANSION_1F =   { height = 66, left = 6, right = 6, back = 9,  front = 1 },
  POWER_PLANT =          { height = 62, left = 6, right = 6, back = 8,  front = 1 },
  SAFFRON_GYM =          { height = 58, left = 5, right = 5, back = 8,  front = 1 },
  FIGHTING_DOJO =        { height = 54, left = 5, right = 5, back = 7,  front = 1 },
  CINNABAR_LAB =         { height = 58, left = 5, right = 5, back = 8,  front = 1 },
  PEWTER_MUSEUM_1F =     { height = 54, left = 5, right = 5, back = 7,  front = 1 },
}

local TALL_DESTINATION_KEYWORDS = {
  { "SILPH_CO", TALL_DESTINATIONS.SILPH_CO_1F },
  { "POKEMON_TOWER", TALL_DESTINATIONS.POKEMON_TOWER_1F },
  { "CELADON_MART", TALL_DESTINATIONS.CELADON_MART_1F },
  { "CELADON_MANSION", TALL_DESTINATIONS.CELADON_MANSION_1F },
  { "POKEMON_MANSION", TALL_DESTINATIONS.POKEMON_MANSION_1F },
  { "POWER_PLANT", TALL_DESTINATIONS.POWER_PLANT },
  { "SAFFRON_GYM", TALL_DESTINATIONS.SAFFRON_GYM },
  { "FIGHTING_DOJO", TALL_DESTINATIONS.FIGHTING_DOJO },
  { "CINNABAR_LAB", TALL_DESTINATIONS.CINNABAR_LAB },
  { "MUSEUM", TALL_DESTINATIONS.PEWTER_MUSEUM_1F },
}

local function tallSpecForDestination(destMap)
  if type(destMap) ~= "string" then return nil end
  local direct = TALL_DESTINATIONS[destMap]
  if direct then return direct end
  for _, row in ipairs(TALL_DESTINATION_KEYWORDS) do
    if destMap:find(row[1], 1, true) then return row[2] end
  end
  return nil
end

local ELIGIBLE = {
  CHARIZARD = { dex = 6, label = "CHARIZARD" },
  PIDGEOT = { dex = 18, label = "PIDGEOT" },
  FEAROW = { dex = 22, label = "FEAROW" },
  GOLBAT = { dex = 42, label = "GOLBAT" },
  AERODACTYL = { dex = 142, label = "AERODACTYL" },
  ARTICUNO = { dex = 144, label = "ARTICUNO" },
  ZAPDOS = { dex = 145, label = "ZAPDOS" },
  MOLTRES = { dex = 146, label = "MOLTRES" },
  DRAGONAIR = { dex = 148, label = "DRAGONAIR" },
  DRAGONITE = { dex = 149, label = "DRAGONITE" },
}

local ELIGIBLE_BY_DEX = {}
for species, cfg in pairs(ELIGIBLE) do ELIGIBLE_BY_DEX[cfg.dex] = species end

-- Vertical seat height above the mount card and a tiny world-depth offset
-- that keeps the two transparent cards from occupying exactly the same
-- plane. 3RD places the rider toward the camera behind the facing direction;
-- the orbit cameras look from the south, so they use a small southward shift.
local DEFAULT_RIDER_OFFSET = {
  lift = 6.5, depth = 0.34, orbitX = 0.0, orbitY = 0.34, eye = 18.0,
}

-- These are visual seat adjustments only, not different flight statistics.
local RIDER_OFFSETS = {
  CHARIZARD = { lift = 7.0, depth = 0.35, orbitX = 0.0, orbitY = 0.35, eye = 18.0 },
  PIDGEOT = { lift = 6.0, depth = 0.30, orbitX = 0.0, orbitY = 0.30, eye = 17.0 },
  FEAROW = { lift = 6.0, depth = 0.32, orbitX = 0.0, orbitY = 0.32, eye = 17.5 },
  GOLBAT = { lift = 5.5, depth = 0.32, orbitX = 0.0, orbitY = 0.32, eye = 17.0 },
  AERODACTYL = { lift = 6.5, depth = 0.36, orbitX = 0.0, orbitY = 0.36, eye = 18.0 },
  ARTICUNO = { lift = 6.5, depth = 0.34, orbitX = 0.0, orbitY = 0.34, eye = 18.0 },
  ZAPDOS = { lift = 6.5, depth = 0.34, orbitX = 0.0, orbitY = 0.34, eye = 18.0 },
  MOLTRES = { lift = 6.5, depth = 0.34, orbitX = 0.0, orbitY = 0.34, eye = 18.0 },
  DRAGONAIR = { lift = 5.5, depth = 0.32, orbitX = 0.0, orbitY = 0.32, eye = 17.0 },
  DRAGONITE = { lift = 7.0, depth = 0.35, orbitX = 0.0, orbitY = 0.35, eye = 18.0 },
}

local FACING_DELTA = {
  up = { 0, -1 }, down = { 0, 1 },
  left = { -1, 0 }, right = { 1, 0 },
}

local function facingFromYaw(yaw)
  local s, c = math.sin(yaw or 0), math.cos(yaw or 0)
