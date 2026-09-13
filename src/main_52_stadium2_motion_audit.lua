(function()
-- -------------------------------------------------------------------------
-- Stadium 2 mount-motion audit / alpha.9 tuning pass.
--
-- Alpha.8 proved the architecture but several Ground/Surf amplitudes were
-- sub-pixel in the voxel world, so the presentation could be technically
-- active while remaining visually indistinguishable from the ordinary idle.
-- This follow-up keeps the safe rule (authentic Stadium skeletons only; no
-- guessed bone gaits) while making role motion visibly meaningful.
--
-- It also fixes Suicune's amphibious presentation: Ground Ride keeps lifecycle
-- ownership on water, but roleFor() switches to "water". Alpha.8 had no
-- WATER.SUICUNE profile, which made profileFor() return nil and silently
-- disabled the whole-model motion layer during water running.
-- -------------------------------------------------------------------------

local warned = {}

local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  if mod.log and mod.log.warn then pcall(mod.log.warn, mod.log, fmt, ...) end
end

local function findUpvalue(fn, wanted)
  if type(fn) ~= "function" or not (debug and debug.getupvalue) then return nil end
  for index = 1, 160 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return index, value end
  end
  return nil
end

local function apply(row, values)
  if type(row) ~= "table" then return false end
  for key, value in pairs(values or {}) do row[key] = value end
  return true
end

local motion = mod.exports and mod.exports.stadium3DMountMotion or nil
local _, profileFor = findUpvalue(motion and motion.profile, "profileFor")
local _, FLIGHT = findUpvalue(profileFor, "FLIGHT")
local _, GROUND = findUpvalue(profileFor, "GROUND")
local _, WATER = findUpvalue(profileFor, "WATER")
local _, BY_DEX = findUpvalue(profileFor, "BY_DEX")

local installed = type(FLIGHT) == "table" and type(GROUND) == "table"
  and type(WATER) == "table" and type(BY_DEX) == "table"

if installed then
  -- Flight already benefits strongly from banking and climb/dive. Only the
  -- deliberately subtle / very large profiles need more readable amplitude.
  local flightTune = {
    DRAGONAIR = { bob=.72, bobIdle=.28, pitch=4.0, climb=5.5, bank=6.0, moveRate=1.08 },
    XATU      = { bob=.44, bobIdle=.22, pitch=4.0, climb=5.0, bank=7.0, moveRate=1.08 },
    SKARMORY  = { bob=.44, pitch=5.0, climb=6.0, bank=9.0, moveRate=1.10 },
    LUGIA     = { bob=.52, bobIdle=.18, pitch=6.0, climb=7.0, bank=9.5, moveRate=1.10 },
    HO_OH     = { bob=.50, pitch=5.5, climb=6.5, bank=9.5, moveRate=1.10 },
  }
  for species, values in pairs(flightTune) do apply(FLIGHT[species], values) end

  -- Ground: enough body response to read as a moving mount, while retaining
  -- restrained amplitudes for heavy bipeds that have no trustworthy Stadium
  -- walk/run clip. Values are world pixels / degrees, not bone edits.
  local groundTune = {
    ARCANINE   = { bob=.85, pitch=4.8, bank=3.0, moveRate=1.20, gallopRate=.18 },
    RAPIDASH   = { bob=.95, pitch=5.2, bank=3.2, moveRate=1.22, gallopRate=.20 },
    DODRIO     = { bob=1.00, pitch=4.5, bank=3.5, moveRate=1.22, gallopRate=.18 },
    RHYHORN    = { bob=.55, pitch=3.0, bank=1.8, moveRate=1.10, gallopRate=.12 },
    RHYDON     = { bob=.40, pitch=2.5, bank=1.4, moveRate=1.08, gallopRate=.09 },
    KANGASKHAN = { bob=.48, pitch=2.8, bank=1.6, moveRate=1.10, gallopRate=.10 },
    TAUROS     = { bob=.90, pitch=4.8, bank=3.0, moveRate=1.21, gallopRate=.20 },
    SNORLAX    = { bob=.25, pitch=1.5, bank=.8, moveRate=1.03, gallopRate=.05 },
    MEGANIUM   = { bob=.55, pitch=3.0, bank=1.8, moveRate=1.11, gallopRate=.11 },
    GIRAFARIG  = { bob=.80, pitch=4.2, bank=2.6, moveRate=1.18, gallopRate=.17 },
    URSARING   = { bob=.40, pitch=2.4, bank=1.2, moveRate=1.08, gallopRate=.09 },
    DONPHAN    = { bob=.55, pitch=2.8, bank=1.8, moveRate=1.11, gallopRate=.12 },
    STANTLER   = { bob=.85, pitch=4.5, bank=2.8, moveRate=1.20, gallopRate=.18 },
    RAIKOU     = { bob=.90, pitch=5.2, bank=3.2, moveRate=1.22, gallopRate=.20 },
    ENTEI      = { bob=.75, pitch=4.5, bank=2.8, moveRate=1.18, gallopRate=.17 },
    SUICUNE    = { bob=.85, pitch=5.0, bank=3.2, moveRate=1.21, gallopRate=.20 },
    TYRANITAR  = { bob=.30, pitch=1.8, bank=1.0, moveRate=1.05, gallopRate=.06 },
  }
  for species, values in pairs(groundTune) do apply(GROUND[species], values) end

  -- Surf: buoyancy must be visible at rest and movement/turning should read
  -- clearly, especially on serpentine and ray-shaped swimmers.
  local waterTune = {
    BLASTOISE  = { bob=.70, bobIdle=.45, pitch=3.2, bank=5.0, moveRate=1.12 },
    TENTACRUEL = { bob=.95, bobIdle=.65, pitch=2.8, bank=6.5, moveRate=1.15 },
    GYARADOS   = { bob=1.05, bobIdle=.58, pitch=4.5, bank=8.0, moveRate=1.16 },
    LAPRAS     = { bob=.75, bobIdle=.50, pitch=3.2, bank=5.0, moveRate=1.12 },
    FERALIGATR = { bob=.75, bobIdle=.46, pitch=3.6, bank=5.2, moveRate=1.13 },
    MANTINE    = { bob=1.00, bobIdle=.58, pitch=5.0, bank=10.0, moveRate=1.16 },
    KINGDRA    = { bob=.90, bobIdle=.55, pitch=4.0, bank=7.0, moveRate=1.15 },
    LUGIA      = { bob=.85, bobIdle=.55, pitch=4.5, bank=7.0, moveRate=1.13 },
  }
  for species, values in pairs(waterTune) do apply(WATER[species], values) end

  -- Suicune is NOT added to the Visible Surf roster. This is an extra motion
  -- profile solely for its Ground Ride amphibious state.
  local suicuneWater = {
    role="water", family="amphibious_runner",
    speedRef=76, idleRate=.92, moveRate=1.18, boostRate=0,
    bob=.80, bobIdle=.38, freq=1.30, pitch=4.0, climb=0, bank=6.0,
  }
  WATER.SUICUNE = suicuneWater
  BY_DEX.water = BY_DEX.water or {}
  BY_DEX.water[245] = suicuneWater

  -- Keep public coverage semantically correct: eight normal Visible Surf
  -- species plus one separate amphibious-water presentation.
  local function rows(set, skip)
    local out = {}
    for species, profile in pairs(set or {}) do
      if species ~= skip then
        out[#out + 1] = { species=species, dex=(species == "SUICUNE" and 245 or nil),
          family=profile.family }
      end
    end
    table.sort(out, function(a,b) return tostring(a.species) < tostring(b.species) end)
    return out
  end

  local originalCoverage = motion.coverage
  motion.coverage = function()
    local base = type(originalCoverage) == "function" and originalCoverage() or {}
    base.counts = { flight=16, ground=17, water=8, amphibiousWater=1, roleEntries=41 }
    base.amphibiousWater = {
      { species="SUICUNE", dex=245, family="amphibious_runner" },
    }
    -- Alpha.8's original coverage walks WATER directly; remove the added
    -- Suicune helper so it is never misreported as a ninth Visible Surf mount.
    if type(base.water) == "table" then
      local filtered = {}
      for _, row in ipairs(base.water) do
        if row.species ~= "SUICUNE" then filtered[#filtered + 1] = row end
      end
      base.water = filtered
    end
    return base
  end

  local function validateSet(set, expected, skip)
    local count, malformed = 0, {}
    for species, profile in pairs(set or {}) do
      if species ~= skip then
        count = count + 1
        for _, key in ipairs({ "speedRef", "idleRate", "moveRate", "bob", "freq", "pitch", "bank" }) do
          if tonumber(profile[key]) == nil then
            malformed[#malformed + 1] = tostring(species) .. ":" .. key
          end
        end
      end
    end
    return count, expected, malformed
  end

  motion.tuningRevision = 2
  motion.amphibiousWaterProfile = true
  motion.audit = function()
    local fc, fe, fm = validateSet(FLIGHT, 16)
    local gc, ge, gm = validateSet(GROUND, 17)
    local wc, we, wm = validateSet(WATER, 8, "SUICUNE")
    local malformed = {}
    for _, list in ipairs({ fm, gm, wm }) do
      for _, value in ipairs(list) do malformed[#malformed + 1] = value end
    end
    return {
      clockPatched = motion.installed == true,
      matrixPatched = motion.matrixPatched == true,
      shadowPatched = motion.shadowPatched == true,
      flight = { count=fc, expected=fe },
      ground = { count=gc, expected=ge },
      water = { count=wc, expected=we },
      amphibiousWater = WATER.SUICUNE ~= nil,
      malformed = malformed,
      ok = motion.installed == true and motion.matrixPatched == true
        and fc == fe and gc == ge and wc == we and WATER.SUICUNE ~= nil
        and #malformed == 0,
    }
  end

  local audit = motion.audit()
  if not audit.matrixPatched then
    warnOnce("matrix", "Stadium 2 alpha.9 audit: model motion matrix is not patched; only skeleton cadence can change")
  end
  if not audit.shadowPatched then
    warnOnce("shadow", "Stadium 2 alpha.9 audit: shadow motion matrix is not patched")
  end
  if not audit.ok then
    warnOnce("audit", "Stadium 2 alpha.9 motion audit failed (flight=%d/%d ground=%d/%d surf=%d/%d amphibious=%s malformed=%d)",
      audit.flight.count, audit.flight.expected, audit.ground.count, audit.ground.expected,
      audit.water.count, audit.water.expected, tostring(audit.amphibiousWater), #audit.malformed)
  end

  log("Stadium 2 alpha.9 motion tuning loaded (16 Flight + 17 Ground + 8 Surf + Suicune amphibious; matrix=%s shadow=%s)",
    tostring(motion.matrixPatched == true), tostring(motion.shadowPatched == true))
else
  warnOnce("install", "Stadium 2 alpha.9 motion audit could not resolve alpha.8 profile tables")
end
end)();
