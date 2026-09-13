    for _, id in ipairs(FOLLOWER_MOD_IDS) do
      local okFind, handle = pcall(mod.find, mod, id)
      local ex = okFind and handle and handle.exports or nil
      if ex then
        if type(ex.syncAll) == "function" then
          pcall(ex.syncAll, Game, ow)
        elseif type(ex.sync) == "function" then
          pcall(ex.sync, Game, ow)
        end
      end
    end
  end
  return hasFollowerEntity(ow)
end

local function restoreFollowers(ow)
  local captured = flight.suspended
  flight.suspended = nil
  if not (ow and ow.map) then return false end
  purgeFollowersDuringFlight(ow)
  if syncFollowerMods(ow) then return true end

  if captured and captured.mapId == ow.map.id then
    for _, e in ipairs(captured.npcs or {}) do
      if not contains(ow.npcs, e) then table.insert(ow.npcs, e) end
    end
    for _, e in ipairs(captured.entities or {}) do
      if not contains(ow.entities, e) then table.insert(ow.entities, e) end
    end
    return hasFollowerEntity(ow) or (#(captured.entities or {}) == 0
      and #(captured.npcs or {}) == 0)
  end

  pendingFollowerRestore = { frames = FOLLOWER_RESTORE_FRAMES }
  return false
end

local function occupiedForLanding(ow, x, y)
