(function()
-- Keep Battle Art's 3RD camera genuinely third-person while surfing. The
-- voxel provider treats every non-walkable cell as a possible boom obstacle
-- below CLEAR height. Water is non-walkable for a pedestrian, so a camera
-- travelling behind a surfing player can collapse into the head;
-- FirstPerson.hidePlayer() then correctly hides the player as if it were 1ST.
--
-- DSR changes only the camera collision query, only during Surf + 3RD: water
-- cells are considered clear for the boom while every other collision rule
-- remains owned by Battle Art. 1ST is untouched and therefore keeps hiding
-- the player's own mount/body as intended.

local thirdPerson = dramaticModule("ThirdPerson")

if thirdPerson and type(thirdPerson.reach) == "function"
   and not thirdPerson.dramaticSkyRideSurfReachHook then
  local nativeReach = thirdPerson.reach

  local function patchWaterWalkability(map, patched)
    if not map or patched[map] then return end
    local nativeWalkable = map.isWalkableCell
    if type(nativeWalkable) ~= "function" then return end

    local ownWalkable = rawget(map, "isWalkableCell")
    patched[map] = { own = ownWalkable, hadOwn = ownWalkable ~= nil }

    map.isWalkableCell = function(self, cx, cy, ...)
      local waterFn = self and self.isWaterCell
      if type(waterFn) == "function" then
        local okWater, waterCell = pcall(waterFn, self, cx, cy)
        if okWater and waterCell == true then return true end
      end
      return nativeWalkable(self, cx, cy, ...)
    end
  end

  local function restoreWalkability(patched)
    for map, state in pairs(patched) do
      if state.hadOwn then
        map.isWalkableCell = state.own
      else
        map.isWalkableCell = nil
      end
    end
  end

  function thirdPerson.reach(ow, pivot, bx, by, bz, want)
    local player = ow and ow.player
    if not (player and player.surfing and isThirdPerson()) then
      return nativeReach(ow, pivot, bx, by, bz, want)
    end

    local patched = {}
    patchWaterWalkability(ow.map, patched)
    for _, nb in ipairs(ow.neighbors or {}) do
      patchWaterWalkability(nb and nb.map, patched)
    end

    local results = { pcall(nativeReach, ow, pivot, bx, by, bz, want) }
    restoreWalkability(patched)
    if not results[1] then error(results[2], 0) end
    return unpackArgs(results, 2)
  end

  thirdPerson.dramaticSkyRideSurfReachHook = true
  log("Surf 3RD water-boom compatibility loaded")
end
end)()
