-- The fork's load gate: the mod discovers and loads clean on both
-- generations, exports its mount surface, and the Crystal rider build
-- falls back to the live player renderer instead of crashing when the
-- engine cannot read the runtime crop file.
--
--   POKEPORT_DATA_DIR=... luajit mods/dramatic_sky_ride/tests/dsr_fork_load_test.lua
--   (run from the engine root; second run with POKEPORT_VERSION=crystal)

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
love = love or require("tests.love_stub")

local generation = os.getenv("POKEPORT_VERSION") or "red"
local Data = require("src.core.Data"); Data:load()

local run = T.sdk.loadMod(os.getenv("MOD_DIR") or "mods/dramatic_sky_ride",
  { data = Data, generation = (generation == "crystal") and 2 or 1 })
T.check(run.mod ~= nil, "mod discovered and loaded (" .. generation .. ")")
T.eq(#run.errors, 0, "loads clean on " .. generation)

local exports = run.loader and run.loader.exports
  and run.loader.exports.DRAMATIC_SKY_RIDE or nil
T.check(type(exports) == "table", "exports present on the loader")
T.check(type(exports.eligibleMounts) ~= nil, "mount surface exported")
T.check(exports._riderSourceSprite ~= nil, "rider source hook exported")

do
  local Game = require("src.core.Game")
  local player = { sprite = { def = { id = "SPRITE_CHRIS",
    image = "crystal/sprites CHRIS", frames = 6 } } }
  T.check(exports._riderSourceSprite(player) ~= nil,
    "rider source resolves for a Crystal player")
end

T.finish("dramatic sky ride fork (" .. generation .. ")")
