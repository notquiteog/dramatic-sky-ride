        local baseEye = tonumber(dramaticFirstPerson.EYE_HEIGHT) or 13
        local copy = {}
        for k, v in pairs(me) do copy[k] = v end
        copy.lift = (me.lift or 0) + math.max(0, (cfg.eye or baseEye) - baseEye)
        me = copy
      end
      return innerFrame(me, cx, cy, vw, vh)
    end
    dramaticFirstPerson.dramaticSkyRideFrameHook = true
  end

  if dramaticFirstPerson and not dramaticFirstPerson.dramaticSkyRideMenuHook then
    local innerUpdate = dramaticFirstPerson.update
    function dramaticFirstPerson.update(dt)
      local releaseMouse = flight.active and isFirstPerson()
        and Game.stack and Game.stack:top() ~= Game.overworld
      local window = love and love.window
      local oldHasFocus = releaseMouse and window and window.hasFocus or nil
      local replaced = false
      if oldHasFocus then
        replaced = pcall(function()
          window.hasFocus = function() return false end
        end)
      end

      local beforeYaw = tonumber(dramaticFirstPerson.yaw) or 0
      local ok, result = pcall(innerUpdate, dt)
      if replaced then
        pcall(function() window.hasFocus = oldHasFocus end)
      elseif releaseMouse and love and love.mouse
             and love.mouse.setRelativeMode then
        pcall(love.mouse.setRelativeMode, false)
      end
      if not ok then error(result, 0) end

      local frameDt = tonumber(dt) or (1 / 60)
      local afterYaw = tonumber(dramaticFirstPerson.yaw) or beforeYaw
      local rightX = dramaticFirstPerson.stickX and dramaticFirstPerson.stickX() or 0
      local rightY = dramaticFirstPerson.stickY and dramaticFirstPerson.stickY() or 0
      local manualLook = math.abs(wrapPi(afterYaw - beforeYaw)) > 0.0007
        or math.abs(rightX) > 0.20 or math.abs(rightY) > 0.20
      if manualLook then
        flight.cameraManualTimer = CAMERA_FOLLOW_DELAY
      else
        flight.cameraManualTimer = math.max(0,
          (flight.cameraManualTimer or 0) - frameDt)
      end

      local worldOnTop = Game.stack and Game.stack:top() == Game.overworld
      if flight.active and isFreeCamera() and worldOnTop
         and cameraFollowEnabled() and (flight.cameraManualTimer or 0) <= 0 then
        local targetYaw = nil
        if flight.phase == "cruise"
           and dramaticFirstPerson.moveVector and dramaticFirstPerson.moveWorld then
          local mx, mz = dramaticFirstPerson.moveVector()
          local mag = math.sqrt((mx or 0) * (mx or 0) + (mz or 0) * (mz or 0))
          -- Reverse keeps the camera where the player deliberately left it;
          -- forward and strafing flight can smoothly pull the view behind the
          -- actual course without an abrupt 180-degree turn.
          if mag >= CAMERA_FOLLOW_MIN_INPUT and (mz or 0) > -0.25 then
            local wx, wz = dramaticFirstPerson.moveWorld(mx, mz)
            if wx ~= 0 or wz ~= 0 then targetYaw = math.atan2(wx, wz) end
          end
        end
        if targetYaw then
          local rate = isThirdPerson() and CAMERA_FOLLOW_RATE_3RD
                       or CAMERA_FOLLOW_RATE_1ST
          dramaticFirstPerson.yaw = wrapPi(approachAngle(
            tonumber(dramaticFirstPerson.yaw) or targetYaw,
            targetYaw, rate, frameDt))
        end
      end
      return result
    end
    dramaticFirstPerson.dramaticSkyRideMenuHook = true
  end

  -- Dramatic Shape's free camera already provides continuous analog movement.
  -- Boost used to call the whole input handler a second time, producing uneven
  -- steps and poor camera tracking. Scaling its per-frame speed instead keeps
  -- one movement solve per frame and therefore one smooth trajectory.
  if dramaticFreeMove and not dramaticFreeMove.dramaticSkyRideSpeedHook then
    local innerTick = dramaticFreeMove.tick
    function dramaticFreeMove.tick(state)
      local oldWalk, oldBike = dramaticFreeMove.WALK, dramaticFreeMove.BIKE
      if flight.active and isFreeCamera() and flight.phase == "cruise" then
        local speedPercent = tonumber(optionValue("flight_speed", 100)) or 100
        speedPercent = math.max(50, math.min(200, speedPercent))
        local multiplier = (speedPercent / 100)
          * (1 + (BOOST_MAX_MULTIPLIER - 1) * (flight.boost or 0))
        dramaticFreeMove.WALK = (tonumber(oldWalk) or 1) * multiplier
        dramaticFreeMove.BIKE = (tonumber(oldBike) or 2) * multiplier
      end
      local ok, result = pcall(innerTick, state)
      dramaticFreeMove.WALK, dramaticFreeMove.BIKE = oldWalk, oldBike
      if not ok then error(result, 0) end
      return result
    end
    dramaticFreeMove.dramaticSkyRideSpeedHook = true
  end
end

installDramaticHooks()

local landingCellValid

local function buildGroundFxSprite()
  if not (love and love.graphics and love.graphics.newCanvas) then return nil end
  local dummy = flight.sprite and flight.sprite.def and flight.sprite.def.image
  if not dummy then return nil end
  local canvas = love.graphics.newCanvas(16, 96)
  setNearest(canvas)
  local def = {
    id = "SKY_RIDE_GROUND_FX", image = dummy,
    frames = 6, walker = true, trueColor = true,
  }
  local sprite = SpriteRenderer.new(def, "sky_ride_ground_fx")
  sprite.image = canvas
  return sprite
end

local function groundFxPose(entity)
  local ow = Game.overworld
  local p = ow and ow.player
  if p then
    entity.cellX, entity.cellY = p.cellX, p.cellY
