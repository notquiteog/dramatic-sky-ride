  p.surfing = enabled
  if Game.save then Game.save.onBike = false end
  if ow.syncSurfingPikachu then pcall(ow.syncSurfingPikachu, ow) end
  if enabled and surfMon then p.surfingPikachu = isPikachu(Game, surfMon) end
  local okMusic, Music = pcall(require, "src.core.Music")
  if okMusic and Music then
    if ow.map and Music.playMap then
      pcall(Music.playMap, Game.data, ow.map.id, false, enabled)
    elseif Music.setSurfing then
      pcall(Music.setSurfing, Game.data, enabled)
    end
  end
  return true
end

local function landingCellKind(ow, x, y)
  local map = ow and ow.map
  if not (map and map:inBounds(x, y)) then return nil, nil, "bounds" end
  if occupiedForLanding(ow, x, y) then return nil, nil, "occupied" end
  if map.isWaterCell and map:isWaterCell(x, y) then
    local surfMon = partyMonKnowsMove(Game, "SURF")
    if surfMon then return "water", surfMon end
    return nil, nil, "surf_required"
  end
  if not map:isWalkableCell(x, y) then return nil, nil, "blocked" end
  return "land", nil
end

landingCellValid = function(ow, x, y)
  return landingCellKind(ow, x, y) ~= nil
end

local function findLandingCell(ow)
  local p = ow.player
