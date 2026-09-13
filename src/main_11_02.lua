local handleInput = OverworldState.handleInput
function OverworldState:handleInput(...)
  local args = { ... }
  if not (flight.active and Game.overworld == self) then
    return handleInput(self, unpackArgs(args))
  end

  local input = Game.input
  if flight.phase == "takeoff" or flight.phase == "landing" then return end
  if input and input:wasPressed("a") then
    beginLanding(Game, false)
    return
  end

  return runAsOpenAir(self, function()
    return handleInput(self, unpackArgs(args))
  end)
end

local update = OverworldState.update
function OverworldState:update(dt, ...)
  if flight.active and Game.overworld == self then
    -- Flight state is renderer-independent. VOXEL OFF is now a supported
    -- native 2D presentation, and an unavailable Stadium renderer falls back
    -- to that same 2D path instead of forcing an emergency landing.
    local frameDt = tonumber(dt) or (1 / 60)
    updateBoost(frameDt)
    flight.hudTimer = math.max(0, (flight.hudTimer or 0) - frameDt)
    flight.noticeTimer = math.max(0, (flight.noticeTimer or 0) - frameDt)
    if flight.noticeTimer <= 0 then flight.notice = nil end
