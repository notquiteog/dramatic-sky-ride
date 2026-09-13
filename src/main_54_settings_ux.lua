;(function()
-- -------------------------------------------------------------------------
-- Dramatic Sky Ride settings UX layer.
--
-- Presentation only: this module never changes Flight, Ground Ride, Surf,
-- collision, progression, renderer ownership or any gameplay option value.
-- It only controls which DSR option rows are visible and in what order.
-- -------------------------------------------------------------------------

local SETTINGS_VIEW_KEY = "settings_view"
local SIZE_OVERRIDES_KEY = "size_overrides"
local VIEW_SIMPLE = "simple"
local VIEW_ADVANCED = "advanced"
local SIZE_HIDDEN = "hidden"
local SIZE_EDIT = "edit"

local function appendOptionOnce(row)
  for _, existing in ipairs(OPTION_SCHEMA or {}) do
    if existing.key == row.key then return existing end
  end
  OPTION_SCHEMA[#OPTION_SCHEMA + 1] = row
  return row
end

-- Keep ADVANCED as the conservative default so existing installations retain
-- the complete settings surface until the player explicitly chooses SIMPLE.
appendOptionOnce({
  key = SETTINGS_VIEW_KEY,
  type = "choice",
  label = "SETTINGS VIEW",
  default = VIEW_ADVANCED,
  choices = {
    { "SIMPLE", VIEW_SIMPLE },
    { "ADVANCED", VIEW_ADVANCED },
  },
  help = "Simple shows the main DSR controls. Advanced shows every setting.",
})

appendOptionOnce({
  key = SIZE_OVERRIDES_KEY,
  type = "choice",
  label = "SIZE OVERRIDES",
  default = SIZE_HIDDEN,
  choices = {
    { "HIDDEN", SIZE_HIDDEN },
    { "EDIT", SIZE_EDIT },
  },
  help = "Show or hide individual Pokemon mount-size overrides. Values are never reset.",
})

-- Improve user-facing wording without changing any persistent option key.
local LABEL_RENAMES = {
  pokedex_mount_sizes = "REALISTIC MOUNT SIZES",
  show_followers_while_mounted = "SHOW FOLLOWERS",
  ground_hud = "GALLOP HUD",
  story_safe = "QUEST COLLISIONS",
}

for _, row in ipairs(OPTION_SCHEMA or {}) do
  local replacement = LABEL_RENAMES[row.key]
  if replacement then row.label = replacement end
end

-- Republish the complete schema once, after all previous chunks have appended
-- their rows. Gen1Recomp replaces a mod's schema on define(), so never publish
-- a reduced schema: hidden values and RESET DEFAULTS keep the exact 0.2.0
-- option contract.
if mod.options and mod.options.define then mod.options:define(OPTION_SCHEMA) end

local function optionString(key, fallback)
  local value = optionValue(key, fallback)
  if value == nil then return fallback end
  return tostring(value):lower()
end

local function simpleView()
  return optionString(SETTINGS_VIEW_KEY, VIEW_ADVANCED) == VIEW_SIMPLE
end

local function sizeEditorVisible()
  return optionString(SIZE_OVERRIDES_KEY, SIZE_HIDDEN) == SIZE_EDIT
end

local function modInstalled(id)
  if not mod.find then return false end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle ~= nil
end

local function wildSkiesInstalled()
  local api = mod.exports and mod.exports.wildSkies
  if api and type(api.installed) == "function" then
    local ok, installed = pcall(api.installed)
    if ok then return installed == true end
  end
  return modInstalled("wild_skies")
end

local function flyingMusicAvailable()
  local listFn = mod.exports and mod.exports.flyingMusicTracks
  if type(listFn) ~= "function" then return false end
  local ok, tracks = pcall(listFn)
  return ok and type(tracks) == "table" and #tracks > 0
end

local function stadiumRelevant()
  local api = mod.exports and mod.exports.stadiumCompatibility
  if api and type(api.installed) == "function" then
    local ok, installed = pcall(api.installed)
    if ok and installed == true then return true end
  end
  return modInstalled("STADIUM_OVERWORLD_MODELS")
end

local SIMPLE_ORDER = {
  SETTINGS_VIEW_KEY,
  "show_rider",
  "flight_speed",
  "ground_speed",
  "manual_altitude",
  "visible_surf_mounts",
  "pokedex_mount_sizes",
  "mount_hints",
  "air_encounters",
  "flying_music",
  "flight_mount_renderer",
}

local ADVANCED_ORDER = {
  SETTINGS_VIEW_KEY,

  -- General
  "show_rider",
  "mount_cries",
  "mount_hints",
  "mount_menu",
  "show_followers_while_mounted",
  "flight_feedback",

  -- Flight
  "flight_speed",
  "manual_altitude",
  "vertical_speed",
  "altitude_display",
  "flight_boost",
  "camera_follow",
  "camera_altitude",
  "landing_marker",
  "dynamic_shadow",
  "air_encounters",
  "mount_shortcut",

  -- Ground Ride
  "ground_speed",
  "ground_gallop",
  "ground_hud",
  "ground_dust",
  "reverse_ledge_jumps",
  "remount_after_battle",

  -- Surf
  "visible_surf_mounts",

  -- Progression
  "require_fly_move",
  "badge_checks",
  "story_gates",
  "discovery_gates",
  "story_safe",

  -- Visual / integration
  "flight_mount_renderer",
  "pokedex_mount_sizes",
  "flying_music",
  SIZE_OVERRIDES_KEY,
}

local SCHEMA_BY_KEY = {}
local LABEL_TO_KEY = {}
for _, def in ipairs(OPTION_SCHEMA or {}) do
  if type(def) == "table" and type(def.key) == "string" then
    SCHEMA_BY_KEY[def.key] = def
    if type(def.label) == "string" then LABEL_TO_KEY[def.label] = def.key end
  end
end

local function normalized(value)
  return tostring(value or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

local function keyForRow(row)
  if type(row) ~= "table" then return nil end

  -- Gen1Recomp's Mod Manager uses the schema key directly as row.id.
  -- Keep the looser fallbacks for the legacy/global Options screen.
  local direct = type(row.id) == "string" and row.id or nil
  if direct and SCHEMA_BY_KEY[direct] then return direct end

  for _, candidate in ipairs({ row.key, row.optionKey, row.option_key }) do
    if type(candidate) == "string" and SCHEMA_BY_KEY[candidate] then return candidate end
  end

  if direct then
    local ni = normalized(direct)
    for key in pairs(SCHEMA_BY_KEY) do
      local nk = normalized(key)
      if ni == nk or ni:match("_" .. nk .. "$") then return key end
    end
  end

  local label = row.label
  if type(label) == "string" and LABEL_TO_KEY[label] then return LABEL_TO_KEY[label] end
  return nil
end

local function isSizeOverride(key)
  return type(key) == "string" and key:match("^mount_size_") ~= nil
end

local function simpleKeyVisible(key)
  if isSizeOverride(key) then return false end
  if key == "air_encounters" then return wildSkiesInstalled() end
  if key == "flying_music" then return flyingMusicAvailable() end
  if key == "flight_mount_renderer" then return stadiumRelevant() end
  for _, wanted in ipairs(SIMPLE_ORDER) do
    if key == wanted then return true end
  end
  return false
end

local function advancedKeyVisible(key)
  if isSizeOverride(key) then return sizeEditorVisible() end
  return true
end

local function indexMap(order)
  local out = {}
  for i, key in ipairs(order) do out[key] = i end
  return out
end

local SIMPLE_INDEX = indexMap(SIMPLE_ORDER)
local ADVANCED_INDEX = indexMap(ADVANCED_ORDER)

local function visibleKey(key)
  if simpleView() then return simpleKeyVisible(key) end
  return advancedKeyVisible(key)
end

local function rowRank(key)
  local order = simpleView() and SIMPLE_INDEX or ADVANCED_INDEX
  return order[key] or (isSizeOverride(key) and 10000 or 5000)
end

local function sortEntries(entries)
  table.sort(entries, function(a, b)
    local ai, bi = rowRank(a.key), rowRank(b.key)
    if ai ~= bi then return ai < bi end
    return a.key < b.key
  end)
  return entries
end

-- Legacy/global OPTIONS hook. Some Gen1Recomp builds expose mod rows here.
-- Keep unrelated rows in place and only decorate rows we can identify as DSR.
local function decorateGlobalRows(out)
  local dsr = {}
  local firstDsr = nil

  for i = #out, 1, -1 do
    local key = keyForRow(out[i])
    if key then
      firstDsr = i
      table.insert(dsr, 1, { row = table.remove(out, i), key = key })
    end
  end

  if not firstDsr then return out end -- fail open

  local visible = {}
  for _, entry in ipairs(dsr) do
    if visibleKey(entry.key) then visible[#visible + 1] = entry end
  end
  sortEntries(visible)

  local insertAt = math.min(firstDsr, #out + 1)
  for i, entry in ipairs(visible) do
    table.insert(out, insertAt + i - 1, entry.row)
  end
  return out
end

mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  return decorateGlobalRows(out)
end)

-- Current Gen1Recomp displays a mod's options in ManagerState rather than in
-- the vanilla/global OptionsMenu. buildOptionRows() receives the COMPLETE DSR
-- schema and produces rows whose ids are the option keys. Decorate the returned
-- rows, not the schema, so hidden settings keep their defaults/persisted values
-- and RESET DEFAULTS still resets the complete schema.
do
  local okManager, ManagerState = pcall(require, "src.mods.ManagerState")
  if okManager and ManagerState and type(ManagerState.buildOptionRows) == "function"
      and not ManagerState.dramaticSkyRideSettingsUXHook then
    local rawBuildOptionRows = ManagerState.buildOptionRows

    local function decorateManagerRows(rows)
      if type(rows) ~= "table" then return rows end
      local entries = {}
      local passthrough = {}
      local resetRow = nil

      for _, row in ipairs(rows) do
        local id = type(row) == "table" and row.id or nil
        if id == "__reset" then
          resetRow = row
        elseif type(id) == "string" and SCHEMA_BY_KEY[id] then
          if visibleKey(id) then entries[#entries + 1] = { row = row, key = id } end
        else
          -- Preserve future engine-owned rows we do not recognise.
          passthrough[#passthrough + 1] = row
        end
      end

      sortEntries(entries)
      local out = {}
      for _, entry in ipairs(entries) do out[#out + 1] = entry.row end
      for _, row in ipairs(passthrough) do out[#out + 1] = row end
      if resetRow then out[#out + 1] = resetRow end
      return out
    end

    function ManagerState:buildOptionRows(m, schema)
      local rows = rawBuildOptionRows(self, m, schema)
      if m and m.id == mod.id then return decorateManagerRows(rows) end
      return rows
    end

    -- ManagerState caches optionRows when OPTIONS is opened. Rebuild only when
    -- one of DSR's two presentation switches changes so SIMPLE/ADVANCED and
    -- HIDDEN/EDIT take effect on the same keypress.
    if type(ManagerState.updateOptions) == "function" then
      local rawUpdateOptions = ManagerState.updateOptions
      function ManagerState:updateOptions(input)
        local isDsr = self.currentMod and self.currentMod.id == mod.id
        local beforeView = isDsr and optionString(SETTINGS_VIEW_KEY, VIEW_ADVANCED) or nil
        local beforeSizes = isDsr and optionString(SIZE_OVERRIDES_KEY, SIZE_HIDDEN) or nil
        local focused = isDsr and self.optionRows and self.optionRows[self.cursor or 1] or nil
        local focusedId = type(focused) == "table" and focused.id or nil

        local result = rawUpdateOptions(self, input)

        if isDsr then
          local afterView = optionString(SETTINGS_VIEW_KEY, VIEW_ADVANCED)
          local afterSizes = optionString(SIZE_OVERRIDES_KEY, SIZE_HIDDEN)
          if beforeView ~= afterView or beforeSizes ~= afterSizes then
            local schema = self:schemaFor(self.currentMod)
            if schema then
              self.optionRows = self:buildOptionRows(self.currentMod, schema)

              local wanted = nil
              for i, row in ipairs(self.optionRows or {}) do
                if type(row) == "table" and row.id == focusedId then
                  wanted = i
                  break
                end
              end
              local count = #(self.optionRows or {})
              self.cursor = wanted or math.max(1, math.min(self.cursor or 1, math.max(1, count)))
              self.scroll = 0
            end
          end
        end
        return result
      end
    end

    ManagerState.dramaticSkyRideSettingsUXHook = true
  end
end

-- Backward-compatible live refresh for builds that still surface mod settings
-- through the global OptionsMenu hook above.
do
  local okOptions, OptionsMenu = pcall(require, "src.ui.OptionsMenu")
  if okOptions and OptionsMenu and type(OptionsMenu.update) == "function"
      and not OptionsMenu.dramaticSkyRideSettingsUXHook then
    local inner = OptionsMenu.update
    function OptionsMenu:update(dt)
      local beforeView = optionString(SETTINGS_VIEW_KEY, VIEW_ADVANCED)
      local beforeSizes = optionString(SIZE_OVERRIDES_KEY, SIZE_HIDDEN)
      inner(self, dt)
      local afterView = optionString(SETTINGS_VIEW_KEY, VIEW_ADVANCED)
      local afterSizes = optionString(SIZE_OVERRIDES_KEY, SIZE_HIDDEN)

      if beforeView ~= afterView or beforeSizes ~= afterSizes then
        local rebuilt = OptionsMenu.new(self.game)
        self.rows = rebuilt.rows
        local cancel = #self.rows + 1
        if (self.index or 1) > cancel then self.index = cancel end
        self.scroll = 0
      end
    end
    OptionsMenu.dramaticSkyRideSettingsUXHook = true
  end
end

mod.exports.settingsUX = {
  api = 2,
  simple = simpleView,
  sizeEditorVisible = sizeEditorVisible,
  wildSkiesInstalled = wildSkiesInstalled,
  flyingMusicAvailable = flyingMusicAvailable,
  stadiumRelevant = stadiumRelevant,
}

log("settings UX loaded (view=%s sizeOverrides=%s managerHook=%s)",
  optionString(SETTINGS_VIEW_KEY, VIEW_ADVANCED),
  optionString(SIZE_OVERRIDES_KEY, SIZE_HIDDEN),
  tostring(pcall(require, "src.mods.ManagerState")))
end)();
