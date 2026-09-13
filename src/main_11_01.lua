  map.isWalkableCell = function() return true end
  Collision.occupied = function(entities, x, y, except)
    return storyOccupied(entities, x, y, except)
  end
  Map.defPassable = function() return true end
  if field then field.tilePairs = { land = {}, water = {} } end

  local ok, result = pcall(fn)

  if hadRawWalk then map.isWalkableCell = rawWalk
  else rawset(map, "isWalkableCell", nil) end
  Collision.occupied = oldOccupied
  Map.defPassable = oldDefPassable
  if field then field.tilePairs = oldPairs end

  if not ok then error(result, 0) end
  return result
end

local function updateBoost(dt)
  local input = Game.input
  local held = flight.active and flight.phase == "cruise"
    and flightBoostEnabled() and input and input:isDown("b")
  local target = held and 1 or 0
  local rate = held and BOOST_RAMP_UP or BOOST_RAMP_DOWN
  local step = rate * (tonumber(dt) or (1 / 60))
  if flight.boost < target then
    flight.boost = math.min(target, flight.boost + step)
  elseif flight.boost > target then
    flight.boost = math.max(target, flight.boost - step)
  end
  if held and not flight.boostWasHeld then feedback("boost") end
  flight.boostWasHeld = held
end

