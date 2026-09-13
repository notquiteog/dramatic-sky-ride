(function()
-- alpha.16 first/third-person camera altitude control.
-- Dramatic Shape owns camera pitch. DSR observes that public module state and
-- converts intentional vertical look input into the same requested-altitude
-- channel already used by L2/R2 and Page Up/Page Down.

flight.cameraVerticalInput = flight.cameraVerticalInput or 0
flight.cameraAltitudeWasEngaged = false

-- Replace only DSR's altitude input combiner. Trigger/keyboard input keeps
-- priority; otherwise the most recent camera vertical intent is consumed.
local updateRequestedAltitudeWithoutCamera = updateRequestedAltitude
updateRequestedAltitude = function(dt)
  if not (manualAltitudeEnabled() and flight.phase == "cruise") then
    flight.cameraVerticalInput = 0
    return updateRequestedAltitudeWithoutCamera(dt)
  end

  local triggerDir = altitudeInputDirection()
  if triggerDir ~= 0 then
    flight.cameraVerticalInput = 0
    return updateRequestedAltitudeWithoutCamera(dt)
  end

  local cameraDir = tonumber(flight.cameraVerticalInput) or 0
  flight.cameraVerticalInput = 0
  if not mod.exports.flightRules.cameraAltitudeEnabled() or math.abs(cameraDir) < 0.01 then
    return updateRequestedAltitudeWithoutCamera(dt)
  end

  flight.verticalInput = cameraDir
  local before = flight.requestedAltitude
  flight.requestedAltitude = clamp(before + cameraDir * verticalRate()
    * (tonumber(dt) or (1 / 60)), MIN_MANUAL_HEIGHT, MAX_MANUAL_HEIGHT)
  if math.abs(flight.requestedAltitude - before) > 0.001 then revealAltitude() end
end

local function installCameraAltitudeHook()
  dramaticFirstPerson = dramaticFirstPerson or dramaticModule("FirstPerson")
  if not (dramaticFirstPerson and type(dramaticFirstPerson.update) == "function") then
    return false
  end
  if dramaticFirstPerson.dramaticSkyRideAltitudeHook then return true end

  local innerUpdate = dramaticFirstPerson.update
  dramaticFirstPerson.update = function(dt)
    local beforePitch = tonumber(dramaticFirstPerson.pitch) or 0
    local activeBefore = flight.active and flight.phase == "cruise"
      and isFreeCamera() and mod.exports.flightRules.cameraAltitudeEnabled()
      and Game.stack and Game.stack:top() == Game.overworld

    local result = innerUpdate(dt)

    local activeNow = flight.active and flight.phase == "cruise"
      and isFreeCamera() and mod.exports.flightRules.cameraAltitudeEnabled()
      and Game.stack and Game.stack:top() == Game.overworld
    local afterPitch = tonumber(dramaticFirstPerson.pitch) or beforePitch

    if activeNow then
      -- Dramatic Shape resets pitch when entering 1ST/3RD. Ignore that first
      -- frame so switching camera modes never changes altitude by itself.
      if flight.cameraAltitudeWasEngaged and activeBefore then
        local rightY = dramaticFirstPerson.stickY and dramaticFirstPerson.stickY() or 0
        local intent = 0
        if math.abs(rightY) > 0.20 then
          -- Mirror Dramatic Shape's dead-zone + squared stick response so the
          -- altitude rate feels proportional to the camera's own pitch rate.
          local dead = tonumber(dramaticFirstPerson.STICK_DEAD) or 0.18
          local a = math.abs(rightY)
          a = clamp((a - dead) / math.max(0.01, 1 - dead), 0, 1)
          local curved = a * a
          -- Positive Dramatic Shape pitch looks DOWN, therefore positive stick
          -- Y means descend.
          intent = rightY < 0 and curved or -curved
        else
          local delta = afterPitch - beforePitch
          if math.abs(delta) > 0.0005 then
            local frameDt = math.max(1 / 240, tonumber(dt) or 1 / 60)
            local pitchRate = tonumber(dramaticFirstPerson.STICK_PITCH) or 2.4
            intent = clamp(-delta / math.max(0.01, pitchRate * frameDt), -1, 1)
          end
        end
        flight.cameraVerticalInput = intent
      else
        flight.cameraVerticalInput = 0
      end
    else
      flight.cameraVerticalInput = 0
    end
    flight.cameraAltitudeWasEngaged = activeNow
    return result
  end
  dramaticFirstPerson.dramaticSkyRideAltitudeHook = true
  return true
end

installCameraAltitudeHook()
mod.events:on("game.ready", installCameraAltitudeHook)

log("alpha.16 1ST/3RD camera altitude control loaded")
end)();
