  return nil
end

local function useMountShortcut(game)
  if not mountShortcutEnabled() then return false end
  local ow = mod.exports._mountWorld(game)
  if not mod.exports._mountFreeRoam(game, ow) then return false end
  if flight.active then
    beginLanding(game, false)
    return true
  end
  local mon = preferredMount(game)
  if not mon then
    say(game, "No healthy flying\nmount is available.")
    return true
  end
  startFlight(game, mon)
  return true
end

local function blockExternalActionUntilManualLanding(game)
  if not flight.active then return true end
  notifyHud("LAND FIRST")
  say(game, "Land before using\nthis shortcut.")
  feedback("blocked")
  return false
end

-- Any non-seamless map replacement is an external transition. Route
-- connections and palette reloads explicitly use seamless=true and keep the
-- flight; warps, Escape Rope, Teleport and quest teleports land first.
local setMap = OverworldState.setMap
function OverworldState:setMap(mapId, x, y, facing, opts, ...)
  local seamless = type(opts) == "table" and opts.seamless == true
  if flight.active and Game.overworld == self and not transitionGuard
     and not seamless then
    transitionGuard = true
    if not forceImmediateLand(Game) then clearFlight(self, true) end
    transitionGuard = false
  end
  return setMap(self, mapId, x, y, facing, opts, ...)
end

local startWarpTo = OverworldState.startWarpTo
function OverworldState:startWarpTo(...)
  if flight.active and Game.overworld == self and not transitionGuard then
    transitionGuard = true
    if not forceImmediateLand(Game) then clearFlight(self, true) end
    transitionGuard = false
  end
  return startWarpTo(self, ...)
end

-- Load late (priority 900) and remain outermost around common external
-- shortcuts. Normal game menus are allowed in flight and simply pause the
-- overworld while they are open. Shortcuts that can teleport, use an item,
-- or start another world action are blocked until the player lands manually.
-- H is deliberately used instead of F: Gen1PC Overworld Encounters reserves
-- F/V for follower attacks and processes them directly from love.keypressed.
local gameKeypressed = Game.keypressed
function Game:keypressed(key, ...)
  if key == "h" and useMountShortcut(self) then return end
  if flight.active and (key == "i" or key == "k") then
    if not blockExternalActionUntilManualLanding(self) then return end
  end
  return gameKeypressed(self, key, ...)
end

local gameGamepadpressed = Game.gamepadpressed
function Game:gamepadpressed(joystick, button, ...)
  -- L2/R2 are altitude controls in flight; consume the button-edge so the
  -- engine does not also change global game speed when a trigger is pulled.
  if flight.active and (button ==
