;(function()
-- Gen 1 Surf transition bridge for Dramatic Shape / Battle Art FreeMove.
--
-- The free-camera provider keeps its own continuous world position while the
-- engine keeps the authoritative tile/cell position. Native Surf enters/leaves
-- through a short scripted transition. Reusing the old continuous point across
-- that state change can leave the body clamped against the shoreline even
-- though Player.surfing is already true. Drop only the provider's cached free
-- position when the Gen 1 Surf flag changes; FreeMove re-adopts the live player
-- on its next tick. Grid movement and Gold are untouched.

local generation = mod.exports.runtimeGeneration or {}
local lastPlayer = nil
local lastSurfing = nil
local transitionCount = 0

local function isGen1()
  return type(generation.isGen1) == "function" and generation.isGen1(Game) == true
end

local function freeMoveModule()
  if dramaticFreeMove then return dramaticFreeMove end
  local ok, provider = pcall(dramaticModule, "FreeMove")
  if ok and provider then dramaticFreeMove = provider end
  return dramaticFreeMove
end

local function resetAfterSurfTransition(ow, player)
  if not (isGen1() and ow and player) then return false end
  local free = freeMoveModule()
  if free and type(free.drop) == "function" then
    pcall(free.drop)
  end

  -- A shoreline transition may leave the cosmetic wall-bonk clock armed.
  -- Clear only idle movement cosmetics; never unlock a scripted/cutscene move.
  if not player.moving and not player.inputLocked then
    player.bumpFrames = nil
    player.turnArmed = true
  end
  transitionCount = transitionCount + 1
  return true
end

local function observeSurfState(ow)
  if not isGen1() then
    lastPlayer, lastSurfing = nil, nil
    return
  end
  local player = ow and ow.player
  if not player then
    lastPlayer, lastSurfing = nil, nil
    return
  end

  local surfing = player.surfing == true
  if player ~= lastPlayer then
    lastPlayer = player
    lastSurfing = surfing
    -- A save can boot directly on water. Make FreeMove adopt that loaded
    -- position instead of retaining a provider point from the previous world.
    if surfing then resetAfterSurfTransition(ow, player) end
    return
  end

  if lastSurfing ~= surfing then
    resetAfterSurfTransition(ow, player)
    lastSurfing = surfing
  end
end

-- Catch the immediate/manual path when the native method flips the flag in
-- the same call. Delayed yes/no/script transitions are caught by update below.
local function wrapSurfMethod(name)
  local native = OverworldState[name]
  if type(native) ~= "function" then return end
  OverworldState[name] = function(self, ...)
    local player = self and self.player
    local before = player and player.surfing == true or false
    local results = { native(self, ...) }
    player = self and self.player
    local after = player and player.surfing == true or false
    if isGen1() and player and before ~= after then
      resetAfterSurfTransition(self, player)
      lastPlayer, lastSurfing = player, after
    end
    return unpackArgs(results)
  end
end

wrapSurfMethod("useSurfFieldMove")
wrapSurfMethod("trySurf")

local previousGen1SurfUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = previousGen1SurfUpdate(self, dt, ...)
  if Game.overworld == self then observeSurfState(self) end
  return result
end

mod.exports.gen1SurfRuntime = {
  transitionCount = function() return transitionCount end,
  surfing = function()
    local ow = Game.overworld
    return ow and ow.player and ow.player.surfing == true or false
  end,
}

log("Gen1 Surf/FreeMove transition bridge loaded")
end)();
