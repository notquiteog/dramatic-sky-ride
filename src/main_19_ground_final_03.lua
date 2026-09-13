  local fx, fy = Collision.target(p.cellX, p.cellY, dir)
  if not self.map:inBounds(fx, fy) then return false end
  local front = self.map:cellTile(fx, fy)
  local lx, ly = Collision.target(fx, fy, dir)

  -- Do not jump through an NPC/object occupying the ledge cell itself.
  if Collision.occupied(self.entities, fx, fy, p)
     or storyOccupied(self.entities, fx, fy, p) then return false end

  local crossesConnection = not self.map:inBounds(lx, ly)
  local landingTile
  if crossesConnection then
    local dest, tilesetDef, cx, cy = connectedLandingSafe(self, dir)
    if not dest then return false end
    landingTile = Map.defCellTile(dest, tilesetDef, cx, cy)
  else
    if not inBoundsLandingSafe(self, lx, ly) then return false end
    landingTile = self.map:cellTile(lx, ly)
  end

  local opposite = { up = "down", down = "up", left = "right", right = "left" }
  local original = opposite[dir]
  for _, ledge in ipairs(Game.data.field.ledges or {}) do
    if (ledge.tileset or "OVERWORLD") == tileset then
      local native = ledge.facing == dir and ledge.input == dir
        and ledge.standingTile == standing and ledge.ledgeTile == front
      local reverse = lot1Option("reverse_ledge_jumps", true) == true
        and original and ledge.facing == original and ledge.input == original
        and ledge.ledgeTile == front and landingTile == ledge.standingTile
      if native or reverse then
        return startGroundLedgeHop(self, dir, crossesConnection)
      end
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Mounted interactions and incompatible actions
-- ---------------------------------------------------------------------------

local function actionDismountEnabled()
  -- Fixed safety rule: normal conversations/signs stay mounted, but actions
  -- that need the vanilla player or a field-action state always dismount.
  return true
end

local function hiddenEntryAt(list, mapId, x, y, facing)
  for _, entry in ipairs(list and list[mapId] or {}) do
    if tonumber(entry.x) == x and tonumber(entry.y) == y
       and (not entry.facing or entry.facing == facing) then
      return entry
    end
  end
  return nil
end

local function interactionNeedsDismount(self, fx, fy)
  if not actionDismountEnabled() then return false end

  local npc = self:npcAtCell(fx, fy)
  if npc and npc.def and npc.def.item then return true end

  local field = Game.data and Game.data.field or {}
  if hiddenEntryAt(field.hiddenItems, self.map.id, fx, fy) then return true end
  if hiddenEntryAt(field.hiddenCoins, self.map.id, fx, fy) then return true end
  if hiddenEntryAt(field.slotMachines, self.map.id, fx, fy, self.player.facing) then return true end

  local extras = field.hiddenExtras or {}
  if hiddenEntryAt(extras.pcTiles, self.map.id, fx, fy, self.player.facing) then return true end
  if self.map.id == "BILLS_HOUSE" and fx == 1 and fy == 4
     and self.player.facing == "up" then return true end
  return false
end

local lot1Interact = OverworldState.interact
function OverworldState:interact(...)
  if ground.active and Game.overworld == self then
    local fx, fy = self.player:facingCell()
    if interactionNeedsDismount(self, fx, fy) then
      stopGroundRide(Game, "interaction")
    end
  end
  -- NPC conversations, signs, shelves and simple examinations intentionally
  -- remain mounted and go through the engine's normal interaction path.
  return lot1Interact(self, ...)
end

local function dismountForAction(reason)
  if ground.active and actionDismountEnabled() then
    stopGroundRide(Game, reason or "field_action")
  end
end

if OverworldState.useCutFieldMove then
  local lot1UseCut = OverworldState.useCutFieldMove
  function OverworldState:useCutFieldMove(...)
    local result = lot1UseCut(self, ...)
    if result == "ok" then dismountForAction("cut") end
    return result
  end
end

if OverworldState.useSurfFieldMove then
  local lot1UseSurf = OverworldState.useSurfFieldMove
  function OverworldState:useSurfFieldMove(...)
    local result = lot1UseSurf(self, ...)
    if result == "ok" then dismountForAction("surf") end
    return result
  end
end

if OverworldState.goFishing then
  local lot1GoFishing = OverworldState.goFishing
  function OverworldState:goFishing(...)
    dismountForAction("fishing")
    return lot1GoFishing(self, ...)
  end
end

if OverworldState.flyTo then
  local lot1FlyTo = OverworldState.flyTo
  function OverworldState:flyTo(...)
    dismountForAction("fly_action")
    return lot1FlyTo(self, ...)
  end
end

if OverworldState.beginTeleportOut then
  local lot1TeleportOut = OverworldState.beginTeleportOut
  function OverworldState:beginTeleportOut(...)
    dismountForAction("escape_action")
    return lot1TeleportOut(self, ...)
  end
end

local lot1CheckBoulderPush = OverworldState.checkBoulderPush
function OverworldState:checkBoulderPush(dir, ...)
  if ground.active and actionDismountEnabled() and self.strengthActive then
    local fx, fy = Collision.target(self.player.cellX, self.player.cellY, dir)
    if self:pushableAtCell(fx, fy) then dismountForAction("strength") end
  end
  return lot1CheckBoulderPush(self, dir, ...)
end

-- ---------------------------------------------------------------------------
-- Final Ground-only update: landing effects, robust remount and integrity
-- ---------------------------------------------------------------------------

local lot1Update = OverworldState.update
function OverworldState:update(dt, ...)
  local p = self.player
  local wasHopping = ground.active and p and p.hopFrames and p.hopFrames > 0
  local result = lot1Update(self, dt, ...)
  p = self.player

  if ground.active and Game.overworld == self then
    if not activeMountStillValid(Game) then
      stopGroundRide(Game, "mount_unavailable")
      notifyHud("MOUNT UNAVAILABLE", 1.8)
    else
      local hopping = p and p.hopFrames and p.hopFrames > 0
      if wasHopping and not hopping and ground.jumpLandingPending then
        ground.jumpLandingPending = nil
        if lot1Option("ground_dust", true) and self.startDustAnim and not self.dustAnim then
          pcall(self.startDustAnim, self, p.cellX, p.cellY)
        end
        feedback("landing")
      end
      if ground.riderEntity then
        ground.riderEntity.pose = groundRiderPose
      end
    end
  end

  if not ground.active then tryBattleRemount(self) end
  return result
end

mod.exports.preferredGroundMountIndex = function()
