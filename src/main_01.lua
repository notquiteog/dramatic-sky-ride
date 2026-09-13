-- Dramatic Sky Ride
-- Multi-camera flying-mount prototype for Gen1Recomp + Dramatic Shape.
--
-- Design goals for this alpha:
--   * Dramatic Shape remains installed separately and is not overwritten.
--   * PokePC follower art is read from the user's existing installation.
--   * The player's normal entity becomes the flying mount temporarily, so
--     Dramatic Shape's existing pose/lift, shadow and third-person camera
--     paths carry it without replacing Dramatic Shape's rendering pipeline.
--   * Ground collisions and per-cell events are bypassed only while this
--     mod's flight state is active, then restored immediately.

local mod = ...

local Game = require("src.core.Game")
local Map = require("src.world.Map")
local Player = require("src.world.Player")
local Collision = require("src.world.Collision")
local SpriteRenderer = require("src.render.SpriteRenderer")
local Assets = require("src.render.Assets")
local Pipelines = require("src.render.Pipelines")
local TextBox = require("src.render.TextBox")
local Strings = require("src.core.Strings")
local Font = require("src.render.Font")
local OverworldState = require("src.world.OverworldController")
local PikachuFollower = require("src.world.PikachuFollower")
local unpackArgs = table.unpack or unpack

-- Gen 1 exposes the live map as `game.overworld` and keeps it on top of the
-- state stack. Gold exposes it as `game.world`; an EMPTY stack is free-roam.
-- Mod callbacks receive the native Game2 instance rather than this file's
-- Gen2Compat facade, so every user-facing mount entry must normalize both
-- shapes before it checks whether the field is ready.
mod.exports._mountWorld = function(game)
  if not game then return nil end
  return game.overworld or game.world
end

mod.exports._mountFreeRoam = function(game, world)
  world = world or mod.exports._mountWorld(game)
  if not (game and world and world.player and world.map and game.stack) then
    return false
  end
  local top = game.stack:top()
  if top ~= nil then return top == world end
  if type(world.acceptsMenuInput) == "function" then
    local ok, accepted = pcall(world.acceptsMenuInput, world)
    return ok and accepted == true
  end
  return false
end

-- Gold's Party/Mount screens sit over the START menu. A field action must
-- clear that whole UI stack, just like PartyMenu:exitToField does for native
-- field moves. Gen 1 keeps its established single-pop behaviour.
mod.exports._closeMountMenus = function(game)
  local world = mod.exports._mountWorld(game)
  local stack = game and game.stack
  if not (world and stack) then return end
  if game.world == world and type(stack.clear) == "function" then
    stack:clear()
  elseif stack:top() ~= nil then
    stack:pop()
  end
end

-- These compatibility fallbacks only need the top-level manifest id. Avoid
-- importing src.link.Json for that tiny read: Gen1Recomp correctly treats all
-- src.link.* modules as network-gated even when used only as a JSON parser.
local function manifestId(raw)
  if type(raw) ~= "string" then return nil end
  return raw:match('"id"%s*:%s*"([^"]+)"')
end

local VOXEL_FULL_LEVEL = 1
local FIRST_PERSON_LEVEL = 6
local THIRD_PERSON_LEVEL = 7
local MAX_VOXEL_LEVEL = 7
local CRUISE_HEIGHT = 34
local MIN_MANUAL_HEIGHT = 20
local MAX_MANUAL_HEIGHT = 96
local TERRAIN_CLEARANCE = 2
local TAKEOFF_RATE = 90
local LANDING_RATE = 120
local MANUAL_FOLLOW_RATE = 90
local OBSTACLE_CLIMB_RATE = 105
local OBSTACLE_DESCEND_RATE = 45
local LANDING_RADIUS = 6 -- emergency landing search only
local ALTITUDE_HUD_SECONDS = 2.0
local NOTICE_HUD_SECONDS = 1.5
local TRIGGER_THRESHOLD = 0.35
local RIDER_CROP_HEIGHT = 13
local RIDER_CROP_Y = 1
local RIDER_RUNTIME_DIR = "dramatic_sky_ride_runtime"
local GROUND_FX_VISIBLE_HEIGHT = 58
local BOOST_RAMP_UP = 3.5
local BOOST_RAMP_DOWN = 5.0
local BOOST_MAX_MULTIPLIER = 2.0
local FOLLOWER_RESTORE_FRAMES = 8
local CAMERA_FOLLOW_DELAY = 0.75
local CAMERA_FOLLOW_RATE_1ST = 1.8
local CAMERA_FOLLOW_RATE_3RD = 3.0
local CAMERA_FOLLOW_MIN_INPUT = 0.18

local VERTICAL_RATES = {
  slow = 24,
  normal = 48,
  fast = 72,
}

-- Gen1Recomp replaces a mod's complete option schema on every define() call.
-- Keep the schema in one shared table so later feature chunks can append rows
-- and republish the complete list without hiding the original flight options.
local OPTION_SCHEMA = {
    {
      key = "show_rider",
      type = "toggle",
      label = "SHOW RIDER",
      default = true,
      help = "Show the trainer seated on the flying Pokemon.",
    },
    {
      key = "manual_altitude",
      type = "toggle",
      label = "MANUAL ALTITUDE",
      default = true,
      help = "R2/Page Up climbs; L2/Page Down descends while flying.",
    },
    {
      key = "altitude_display",
      type = "choice",
      label = "ALTITUDE DISPLAY",
      default = "temporary",
      choices = {
        { "Temporary", "temporary" },
        { "Always", "always" },
        { "Off", "off" },
      },
      help = "When the five-level altitude indicator is visible.",
    },
    {
      key = "vertical_speed",
      type = "choice",
      label = "VERTICAL SPEED",
      default = "normal",
      choices = {
        { "Slow", "slow" },
        { "Normal", "normal" },
        { "Fast", "fast" },
      },
      help = "How quickly the requested flight altitude changes.",
    },
    {
      key = "flight_speed",
      type = "number",
      label = "FLIGHT SPEED",
      default = 100,
      min = 50,
      max = 200,
      step = 10,
      help = "Global horizontal flight speed percentage. 100 keeps the default speed.",
    },
    {
      key = "ground_speed",
      type = "number",
      label = "GROUND SPEED",
      default = 100,
      min = 50,
      max = 200,
      step = 10,
      help = "Global Ground Ride speed percentage. Species differences and gallop still apply.",
    },
    {
      key = "landing_marker",
      type = "toggle",
      label = "LANDING MARKER",
      default = true,
      help = "Show a green or red landing marker while flying low.",
    },
    {
      key = "dynamic_shadow",
      type = "toggle",
      label = "DYNAMIC SHADOW",
      default = true,
      help = "Show a soft ground shadow whose size follows altitude.",
    },
    {
      key = "mount_shortcut",
      type = "toggle",
      label = "MOUNT SHORTCUT",
      default = true,
      help = "H on keyboard or X on controller takes off with the last available mount.",
    },
    {
      key = "flight_boost",
      type = "toggle",
      label = "FLIGHT BOOST",
      default = true,
      help = "Hold B while moving to accelerate smoothly.",
    },
    {
      key = "camera_follow",
      type = "toggle",
      label = "CAMERA FOLLOW",
      default = true,
      help = "Smoothly turn the 1ST/3RD camera toward the actual flight direction.",
    },
    {
      key = "flight_feedback",
      type = "toggle",
      label = "SOUND & RUMBLE",
      default = true,
      help = "Use flight sounds and controller vibration feedback.",
    },
    {
      key = "story_safe",
      type = "toggle",
      label = "STORY SAFE",
      default = true,
      help = "Keep runtime quest characters and barriers solid in flight.",
    },
}

if mod.options and mod.options.define then
  mod.options:define(OPTION_SCHEMA)
end

local function optionValue(key, default)
  if not (mod.options and mod.options.get) then return default end
  local ok, value = pcall(mod.options.get, mod.options, key)
  if not ok or value == nil then return default end
  return value
end

local function showRiderEnabled()
  return optionValue("show_rider", true) == true
end

local function manualAltitudeEnabled()
  return optionValue("manual_altitude", true) == true
end

local function altitudeDisplayMode()
