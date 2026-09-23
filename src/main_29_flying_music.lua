-- Optional Flying Music override.
--
-- DSR reuses the public merged Surf / Bike music records. No private mod
-- directories are inspected and no third-party audio is copied into Ride.
(function()
  local Music = require("src.core.Music")
  local FLYING_MUSIC_NONE = "none"
  local FLYING_MUSIC_OPTION = "flying_music"
  local FLYING_MUSIC_PREFIX = "Music_DSR_Flying_"

  local function loadFlyingMusicCatalog()
    local source = mod:read("audio/flying/tracks.lua")
    if not source then
      mod.log:warn("Flying Music catalog is missing; external pack tracks only")
      return {}
    end

    local chunk, compileErr = load(source,
      "@" .. mod.path .. "/audio/flying/tracks.lua")
    if not chunk then
      mod.log:error("Flying Music catalog did not compile: %s", tostring(compileErr))
      return {}
    end

    local ok, catalog = pcall(chunk)
    if not ok then
      mod.log:error("Flying Music catalog failed to load: %s", tostring(catalog))
      return {}
    end
    if type(catalog) ~= "table" then
      mod.log:error("Flying Music catalog must return a table")
      return {}
    end
    return catalog
  end

  local function ownAssetPath(relative)
    relative = tostring(relative or "")
    if relative == "" then return nil end
    if mod.assets and mod.assets.path then return mod.assets:path(relative) end
    return mod.path .. "/" .. relative
  end

  local function trackFiles(track)
    if type(track) ~= "table" then return nil, nil end
    local intro = track.intro or track.file
    local loop = track.loop or track.loopFile or track.loop_file
    if intro == nil or tostring(intro) == "" then return nil, nil end
    return tostring(intro), loop and tostring(loop) or nil
  end

  local function fsFileExists(path)
    local fs = love and love.filesystem
    if not (fs and fs.getInfo) then return true end
    local ok, info = pcall(fs.getInfo, path)
    return ok and info ~= nil
  end

  local tracksByKey = {}
  local optionChoices = { { "None", FLYING_MUSIC_NONE } }

  local function registerTrack(track, resolvePath, provider)
    local key = type(track) == "table" and tostring(track.key or "") or ""
    local label = type(track) == "table" and tostring(track.label or "") or ""
    local intro, loop = trackFiles(track)
    if key == "" or key == FLYING_MUSIC_NONE or label == "" or not intro then
      mod.log:warn("Ignoring invalid Flying Music catalog row")
      return false
    end
    if tracksByKey[key] then
      mod.log:warn("Ignoring duplicate Flying Music key %s", key)
      return false
    end

    local introPath = resolvePath(intro)
    local loopPath = loop and resolvePath(loop) or nil
    if not introPath or not fsFileExists(introPath) then
      mod.log:warn("Flying Music asset missing for %s: %s", label, tostring(introPath))
      return false
    end
    if loopPath and not fsFileExists(loopPath) then
      mod.log:warn("Flying Music loop asset missing for %s: %s", label, tostring(loopPath))
      return false
    end

    local safeKey = key:gsub("[^%w_]", "_")
    local songId = FLYING_MUSIC_PREFIX .. safeKey
    local def = { file = introPath }
    if loopPath then def.loopFile = loopPath end

    mod.content.music:register(songId, def)
    tracksByKey[key] = {
      key = key,
      label = label,
      intro = introPath,
      loop = loopPath,
      songId = songId,
      provider = provider or "Dramatic Sky Ride",
    }
    optionChoices[#optionChoices + 1] = { label, key }
    return true
  end

  -- Optional local/user-supplied tracks. The public catalog stays empty by
  -- default so DSR does not redistribute commercial music.
  for _, track in ipairs(loadFlyingMusicCatalog()) do
    registerTrack(track, ownAssetPath, "Dramatic Sky Ride")
  end

  -- Definitions are already registered by their owner. Preserve those song
  -- identities and paths, including load-order selection between music packs.
  local public = assert((loadstring or load)(assert(mod:read("lib/RegisteredFlightMusic.lua")),
    "@ride/registered-music"))()(mod)
  local externalCount = 0
  for _, row in ipairs(public) do
    if not tracksByKey[row.key] then
      tracksByKey[row.key] = {
        key = row.key, label = row.label, intro = row.intro, loop = row.loop,
        songId = row.songId, provider = "Registered music",
      }
      optionChoices[#optionChoices + 1] = { row.label, row.key }
      externalCount = externalCount + 1
    end
  end

  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = {
    key = FLYING_MUSIC_OPTION,
    type = "choice",
    label = "FLYING MUSIC",
    default = FLYING_MUSIC_NONE,
    choices = optionChoices,
    help = "Choose a flight theme. Public registered Surf/Bike tracks are optional.",
  }
  if mod.options and mod.options.define then mod.options:define(OPTION_SCHEMA) end

  local activeFlyingSong = nil

  local function selectedFlyingTrack()
    local key = tostring(optionValue(FLYING_MUSIC_OPTION, FLYING_MUSIC_NONE)
      or FLYING_MUSIC_NONE)
    return tracksByKey[key]
  end

  local function playSelectedFlyingMusic()
    if not flight.active then return false end
    local track = selectedFlyingTrack()
    if not track then
      if activeFlyingSong then
        activeFlyingSong = nil
        Music.restoreMap(Game.data)
      end
      return false
    end

    activeFlyingSong = track.songId
    Music.play(Game.data, track.songId, true, { reason = "direct" })
    return true
  end

  local function restoreNormalMapMusic()
    if not activeFlyingSong then return end
    activeFlyingSong = nil
    Music.restoreMap(Game.data)
  end

  -- Map-driven music refreshes while airborne keep the selected flight cue.
  -- Battle, victory, jingle and other direct cues keep their normal priority.
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("music.select", function(next, chosen, ctx)
      local track = flight.active and selectedFlyingTrack() or nil
      if track and ctx and ctx.reason == "map" then
        activeFlyingSong = track.songId
        return next(track.songId, ctx)
      end
      return next(chosen, ctx)
    end)
  end

  local rawStartFlightForMusic = startFlight
  startFlight = function(game, mon)
    local started = rawStartFlightForMusic(game, mon)
    if started and flight.active then playSelectedFlyingMusic() end
    return started
  end

  local rawClearFlightForMusic = clearFlight
  clearFlight = function(ow, landingFeedback, surfMon)
    local hadFlyingMusic = activeFlyingSong ~= nil
    local result = rawClearFlightForMusic(ow, landingFeedback, surfMon)
    if hadFlyingMusic then restoreNormalMapMusic() end
    return result
  end

  mod.events:on("mod.options_changed", function(payload)
    if not (payload and payload.mod == mod.id
        and payload.key == FLYING_MUSIC_OPTION) then return end
    if flight.active then playSelectedFlyingMusic() end
  end)

  mod.exports.flyingMusicTracks = function()
    local out = {}
    for _, pair in ipairs(optionChoices) do
      if pair[2] ~= FLYING_MUSIC_NONE then
        local track = tracksByKey[pair[2]]
        out[#out + 1] = {
          label = pair[1], key = pair[2], provider = track and track.provider or nil,
        }
      end
    end
    return out
  end

  mod.exports.flyingMusic = {
    selected = function()
      local track = selectedFlyingTrack()
      return track and track.key or FLYING_MUSIC_NONE
    end,
    activeSong = function() return activeFlyingSong end,
  }

  log("Flying Music compatibility loaded with %d track(s), %d from public music records",
    #optionChoices - 1, externalCount)
end)()
