-- Ground Ride follower-state bridge.
-- The existing follower helpers store their captured entities in the flight
-- state. Ground Ride mirrors its own capture there before restoration so both
-- mount families use the same proven recovery path.
local groundStartBase = startGroundRide
startGroundRide = function(game, mon)
  local ok = groundStartBase(game, mon)
  if ok and ground.active then flight.suspended = ground.suspended end
  return ok
end

local groundStopBase = stopGroundRide
stopGroundRide = function(game, reason, keepFollowers)
  if ground.active then flight.suspended = ground.suspended end
  -- Followers may safely return before the battle screen or another mode is
  -- entered. A resumed Ground Ride captures them again afterwards.
  return groundStopBase(game, reason, false)
end
