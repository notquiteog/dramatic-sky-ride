      if i ~= lastGroundMountIndex then
        lastGroundMountIndex = i
        saveSet("preferredGroundIndex", i)
      end
      return healthy(mon) and groundSpecies(game, mon) ~= nil
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Safe authored ledges with species-weighted visuals
-- ---------------------------------------------------------------------------

local JUMP_PROFILE = {
  ARCANINE   = { height = 8.5, crouch = 1.0 },
  RAPIDASH   = { height = 9.0, crouch = 1.0 },
  DODRIO     = { height = 10.0, crouch = 0.7 },
  RHYHORN    = { height = 6.5, crouch = 1.4 },
  RHYDON     = { height = 6.0, crouch = 1.6 },
  KANGASKHAN = { height = 7.0, crouch = 1.2 },
  TAUROS     = { height = 8.0, crouch = 1.2 },
  SNORLAX    = { height = 4.5, crouch = 2.0 },
}

local function groundJumpOffset(p)
  if not (p and p.hopFrames and p.hopFrames > 0) then return 0 end
  local total = tonumber(p.hopTotal) or 32
  local t = math.max(0, math.min(1, 1 - p.hopFrames / math.max(1, total)))
  local profile = JUMP_PROFILE[ground.species] or JUMP_PROFILE.TAUROS
  local lift = (profile.height or 8) * math.sin(t * math.pi)
  local crouch = 0
  if t < 0.12 then
    crouch = (profile.crouch or 1) * (1 - t / 0.12)
  end
  -- Positive means move down; negative means lift into the air.
  return crouch - lift
end

-- The validated alpha.15 Player.pose chain accidentally keeps the Ground
-- sprite at logical p.py during a hop. Add a Ground-only visual arc here;
-- flight and Surf outputs pass through untouched.
local lot1PlayerPose = Player.pose
function Player:pose()
  local sprite, px, py, facing, phase, flip, hopping = lot1PlayerPose(self)
  local ow = Game.overworld
  if ground.active and ow and ow.player == self
     and not isSupportedVoxelMode(voxelLevel()) then
    -- In voxel modes Dramatic Shape turns the `hopping` flag into vertical
    -- lift itself; changing world py there would shift the mount across the
    -- ground plane and could disturb the validated camera.
    py = py + groundJumpOffset(self)
    hopping = self.hopFrames and self.hopFrames > 0 or hopping
  end
  return sprite, px, py, facing, phase, flip, hopping
end

local lot1GroundRiderPose = groundRiderPose
groundRiderPose = function(entity)
  local sprite, px, py, facing, phase, flip, hopping = lot1GroundRiderPose(entity)
  local p = Game.overworld and Game.overworld.player
  if ground.active and p and not isSupportedVoxelMode(voxelLevel()) then
    py = py + groundJumpOffset(p)
  end
  return sprite, px, py, facing, phase, flip, hopping
end

local function mapCellHasWarp(map, x, y)
  if not map then return true end
  if map.warpAtCell and map:warpAtCell(x, y) then return true end
  if map.isWarpTileCell and map:isWarpTileCell(x, y) then return true end
  if map.warpPadOrHoleAt and map:warpPadOrHoleAt(x, y) then return true end
  return false
end

local function defHasWarp(def, tilesetDef, x, y)
  for _, warp in ipairs(def and def.warps or {}) do
    if tonumber(warp.x) == x and tonumber(warp.y) == y then return true end
  end
  local tile = Map.defCellTile(def, tilesetDef, x, y)
  if tile == nil then return true end
  for _, id in ipairs(tilesetDef and tilesetDef.doorTiles or {}) do
    if id == tile then return true end
  end
  for _, id in ipairs(tilesetDef and tilesetDef.warpTiles or {}) do
    if id == tile then return true end
  end
  local pads = tilesetDef and tilesetDef.warpPadTiles
  if pads and pads[tile] ~= nil then return true end
  -- Match Map.lua's vanilla fallback for caches whose tileset record does
  -- not yet carry warpPadTiles.
  local fallback = {
    FACILITY = { [0x20] = true, [0x11] = true },
    CAVERN = { [0x22] = true },
    INTERIOR = { [0x55] = true },
  }
  local row = fallback[def and def.tileset]
  return row and row[tile] == true or false
end

local function destinationObjectVisible(def, obj)
  local save = Game.save or {}
  local toggles = save.objectToggles and save.objectToggles[def.id] or {}
  local visible = not obj.hidden
  if obj.name and toggles[obj.name] ~= nil then visible = toggles[obj.name] end
  if obj.item and save.itemsTaken
     and save.itemsTaken[def.id .. "_obj_" .. tostring(obj.index)] then
    visible = false
  end
  if obj.pokemon and save.defeatedTrainers
     and save.defeatedTrainers[def.id .. "_obj_" .. tostring(obj.index)] then
    visible = false
  end
  return visible
end

local function defObjectBlocks(def, x, y)
  for _, obj in ipairs(def and def.objects or {}) do
    if tonumber(obj.x) == x and tonumber(obj.y) == y
       and destinationObjectVisible(def, obj)
       and obj.passable ~= true then
      return true
    end
  end
  return false
end

local function inBoundsLandingSafe(self, x, y)
  local p = self.player
  if mapCellHasWarp(self.map, x, y) then return false end
  if self.map.isWaterCell and self.map:isWaterCell(x, y) then return false end
  if not self.map:isWalkableCell(x, y) then return false end
  if Collision.occupied(self.entities, x, y, p) then return false end
  if storyOccupied(self.entities, x, y, p) then return false end
  return true
end

local function connectedLandingSafe(self, dir)
  local dest, tilesetDef, x, y = self:connectionLanding(dir)
  if not (dest and tilesetDef) then return nil end
  if not Map.defPassable(dest, tilesetDef, x, y, false) then return nil end
  if Map.defIsWaterCell(dest, tilesetDef, x, y) then return nil end
  if defHasWarp(dest, tilesetDef, x, y) then return nil end
  if defObjectBlocks(dest, x, y) then return nil end
  return dest, tilesetDef, x, y
end

local function startGroundLedgeHop(self, dir, crossesConnection)
  local p = self.player
  Sound.play(Game.data, "Ledge")
  p.hopFrames, p.hopTotal = 32, 32
  ground.jumpWasActive = true
  ground.jumpLandingPending = true
  rumble(0.14, 0.24, 0.12)
  if crossesConnection then
    self:scriptMove(p, dir, 1, function() self:checkEdgeExit(dir) end)
  else
    self:scriptMove(p, dir, 2)
  end
  return true
end

-- Fully replace the intermediate alpha.15 wrapper. Non-Ground movement calls
-- the engine's native implementation exactly as before.
function OverworldState:checkLedgeHop(dir)
  if not (ground.active and Game.overworld == self and self.player and self.map) then
    return nativeCheckLedgeHop(self, dir)
  end

  local p = self.player
  local tileset = self.map.def.tileset
  local standing = self.map:cellTile(p.cellX, p.cellY)
