    if syncFollowerMods(self) or pendingFollowerRestore.frames <= 0 then
      pendingFollowerRestore = nil
    end
  end
  return result
end

-- Five-level temporary altitude indicator plus non-blocking landing errors.
-- It is drawn in the overworld UI pass, so it stays crisp and camera-neutral
-- in every supported voxel view.
local drawUI = OverworldState.drawUI
function OverworldState:drawUI(...)
  local result = drawUI(self, ...)
  if not (flight.active and Game.overworld == self and love and love.graphics) then
    return result
  end

  local display = altitudeDisplayMode()
  local showAltitude = display == "always"
    or (display == "temporary" and (flight.hudTimer or 0) > 0)
  if not showAltitude and not flight.notice then return result end

  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, 1)

  if showAltitude then
    Font.drawBox(9, 0, 11, 4)
    Font.draw("ALT", 80, 8)
    local auto = (flight.safetyAltitude or 0)
      > (flight.requestedAltitude or CRUISE_HEIGHT) + 0.01
    if auto then Font.draw("AUTO", 112, 8) end
    local ratio = clamp(((flight.altitude or MIN_MANUAL_HEIGHT)
      - MIN_MANUAL_HEIGHT) / (MAX_MANUAL_HEIGHT - MIN_MANUAL_HEIGHT), 0, 1)
    local level = 1 + math.floor(ratio * 4 + 0.5)
    for i = 1, 5 do
      local x, y = 80 + (i - 1) * 13, 21
      love.graphics.rectangle("line", x + 0.5, y + 0.5, 9, 5)
      if i <= level then love.graphics.rectangle("fill", x + 2, y + 2, 6, 2) end
    end
  end

  if flight.notice then
    Font.drawBox(1, 14, 18, 4)
    local width = Font.width(flight.notice)
    Font.draw(flight.notice, math.floor((160 - width) / 2), 120)
  end

  love.graphics.pop()
  return result
end

-- The normal START menu remains available while flying. Saving is the one
-- vanilla row that cannot safely continue: a save made over water, a roof or
-- another blocked cell would reload the player there without the session-only
-- mount. Replace only that row with a warning and leave the flight untouched;
-- the player closes the menu and lands manually before trying again. Direct
-- writes from another mod still reach the save.writing emergency guard below.
mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
  local out = next(game, items)
  if not flight.active or type(out) ~= "table" then return out end
  local saveLabel = Strings("SAVE")
  for i, item in ipairs(out) do
    if type(item) == "table" and item.label == saveLabel then
      local copy = shallowCopy(item)
      copy.onSelect = function()
        notifyHud("LAND FIRST")
        say(game, "Land before saving.\nYou r