           self.py - lift,
           facing, wingPhase, flip, false
  end
  return sprite, px, py, facing, phase, flip, hopping
end

-- Suppress the ground consequences of cells crossed in the air: encounters,
-- warps underfoot, spinner tiles, poison steps and scripted step triggers.
local onStepComplete = OverworldState.onStepComplete
function OverworldState:onStepComplete(...)
  if flight.active and Game.overworld == self then
    self.standingOnWarp = false
    return
  end
  return onStepComplete(self, ...)
end

local checkTrainerSight = OverworldState.checkTrainerSight
function OverworldState:checkTrainerSight(...)
  if flight.active and Game.overworld == self then return end
  return checkTrainerSight(self, ...)
end

-- Dramatic Shape's FreeMove remains responsible for camera-relative analog
-- movement in 1ST and 3RD. The orbit cameras use Gen1Recomp's ordinary movement. In
-- both cases, for the duration of one input tick only, collision questions
-- answer as open air. Every original function/table is restored before
-- returning, including when the tick raises an error.
local function runAsOpenAir(state, fn)
  local map = state.map
