  local rawWalk = rawget(map, "isWalkableCell")
  local hadRawWalk = rawWalk ~= nil
  local oldOccupied = Collision.occupied
  local oldDefPassable = Map.defPassable
  local field = Game.data and Game.data.field
  local oldPairs = field and field.tilePairs

