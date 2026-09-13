  for _, e in ipairs(ow.entities or {}) do
    if e ~= ow.player and not e.passable then
      if (e.cellX == x and e.cellY == y)
         or (e.targetX == x and e.targetY == y) then
        return true
      end
    end
  end
  return false
end


local function isStoryCriticalEntity(e)
  if not e or e.skyRideRider or e.skyRideGroundFx then return false end
  if isFollowerEntity(e, Game.overworld and Game.overworld.player) then return false end
  local def = e.def or {}
  local id = tostring(e.id or ""):lower()
  return def.runtime == true or def.owner ~= nil
      or e.questId ~= nil or e.quest ~= nil or e.questRuntime == true
      or id:find("quest", 1, true) ~= nil
end

local function storyOccupied(entities, x, y, except)
  if not storySafeEnabled() then return false end
  for _, e in ipairs(entities or {}) do
    if e ~= except and isStoryCriticalEntity(e)
       and ((e.cellX == x and e.cellY == y)
            or (e.targetX == x and e.targetY == y)) then
      return true
    end
  end
  return false
end

-- Water landings deliberately test the move itself rather than the badge.
-- The requested rule is simple: if any party Pokemon knows SURF, the rider
