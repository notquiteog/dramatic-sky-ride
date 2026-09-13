local function amphibiousGroundOwnsWaterVisual()
  local gen2 = mod.exports and mod.exports.gen2Mounts or nil
  if not gen2 then return false end
  if type(gen2.suicuneAmphibiousActive) == "function" then
    local ok, active = pcall(gen2.suicuneAmphibiousActive)
    if ok and active == true then return true end
  end
  -- During the battle -> overworld handoff Ground Ride is intentionally
  -- suspended for a few frames. Keep Suicune as the visual owner throughout
  -- that gap so the generic visible-Surf mount never flashes on screen.
  if type(gen2.battleWaterResumePending) == "function" then
    local ok, pending = pcall(gen2.battleWaterResumePending)
    if ok and pending == true then return true end
  end
  return false
end

local function activateWaterRide(game, requested)
  if amphibiousGroundOwnsWaterVisual() then
    clearWaterRide(mod.exports._mountWorld(game))
    return false
  end
  if mountOption("visible_surf_mounts", true) ~= true then return false end
  local ow = mod.exports._mountWorld(game)
  local mon = preferredWaterMount(game, requested)
  local species = waterSpecies(game, mon)
  local sprite = species and buildWaterSprite(species)
  if not (ow and ow.player and ow.player.surfing and mon and sprite) then
    if species and water.lastFailure then
      local signature = species .. ":" .. tostring(water.lastFailure)
      if water.warnedFailure ~= signature then
        water.warnedFailure = signature
        if mod.log then
          mod.log:warn("Visible Surf mount %s unavailable: %s",
            tostring(species), tostring(water.lastFailure))
        end
      end
    end
    return false
  end
  water.warnedFailure = nil
  water.active, water.mon, water.species, water.sprite = true, mon, species, sprite
  water.riderSprite = select(1, buildRiderSprite(ow.player))
  ensureWaterRider(ow)
  playSpeciesCry(species)
  if mountOption("mount_hints", true) and not mountHintsShown.water then
    mountHintsShown.water = true
  end
  return true
end

local waterPlayerPose = Player.pose
function Player:pose()
  local sprite, px, py, facing, phase, flip, hopping = waterPlayerPose(self)
  local ow = Game.overworld
  if water.active and self.surfing and ow and ow.player == self and water.sprite
     and not amphibiousGroundOwnsWaterVisual() then
    return water.sprite, px, py, facing, phase, flip, hopping
  end
  return sprite, px, py, facing, phase, flip, hopping
end

local alpha15SetSurfingState = setSurfingState
setSurfingState = function(ow, enabled, surfMon)
  local result = alpha15SetSurfingState(ow, enabled, surfMon)
  if enabled and not amphibiousGroundOwnsWaterVisual() then
    activateWaterRide(Game, surfMon)
  else
    clearWaterRide(ow)
  end
  return result
end

local function waterPartyIndex(game, wanted)
  for i, mon in ipairs(game and game.save and game.save.party or {}) do
    if mon == wanted then return i end
  end
  return nil
end

local function resolveWaterBattleMount(snapshot)
  local party = Game.save and Game.save.party or {}
  for _, mon in ipairs(party) do
    if mon == snapshot.mon then return mon end
  end
  local slotted = snapshot.index and party[snapshot.index]
  if slotted and waterSpecies(Game, slotted) == snapshot.species then return slotted end
  if snapshot.nickname and snapshot.nickname ~= "" then
    for _, mon in ipairs(party) do
      if mon.nickname == snapshot.nickname
         and waterSpecies(Game, mon) == snapshot.species then return mon end
    end
  end
  for _, mon in ipairs(party) do
    if waterSpecies(Game, mon) == snapshot.species then return mon end
  end
  return nil
end

mod.events:on("battle.started", function()
  if not (water.active and water.mon and water.species) then return end
  waterBattleResume = {
    mon = water.mon,
    index = waterPartyIndex(Game, water.mon),
    species = water.species,
    nickname = water.mon.nickname,
  }
end)

mod.events:on("battle.ended", function(ev)
  if not waterBattleResume then return end
  waterBattleResume.ended = true
  waterBattleResume.result = ev and ev.result
end)

local function tryWaterBattleResume(self)
  local snapshot = waterBattleResume
  if not (snapshot and snapshot.ended) then return false end
  if not mod.exports._mountFreeRoam(Game, self) then return false end
  waterBattleResume = nil

  if snapshot.result == "lose"
     or mountOption("remount_after_battle", true) ~= true then
    clearWaterRide(self)
    return false
  end

  local mon = resolveWaterBattleMount(snapshot)
  if not (healthy(mon) and waterSpecies(Game, mon) == snapshot.species
          and monKnowsMove(mon, "SURF")) then
    clearWaterRide(self)
    return false
  end

  -- Gold keeps traversal in World.playerState. Mirror it before the later
  -- Gen2 bridge tick so Visible Surf can be restored on this first free frame.
  local nativeState = self.playerState
  if nativeState == "surf" or nativeState == "surf_pika" then
    self.player.surfing = true
  end
  if not self.player.surfing then
    clearWaterRide(self)
    return false
  end

  lastWaterMountIndex = waterPartyIndex(Game, mon) or snapshot.index
  clearWaterRide(self)
  return activateWaterRide(Game, mon)
end

local waterUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = waterUpdate(self, dt, ...)
  if Game.overworld == self and self.player then
    local resumed = tryWaterBattleResume(self)
    if resumed then
      ensureWaterRider(self)
    elseif amphibiousGroundOwnsWaterVisual() then
      if water.active then clearWaterRide(self) end
    elseif self.player.surfing and mountOption("visible_surf_mounts", true) then
      if not water.active then activateWaterRide(Game) end
      if water.active then ensureWaterRider(self) end
    elseif water.active then
      clearWaterRide(self)
    end
  end
  return result
end

mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
  local out = next(game, items, mon, ctx)
  if type(out) ~= "table" then out = items end
  if flight.active then return out end
  local species = waterSpecies(game, mon)
  if not species or not monKnowsMove(mon, "SURF") or (ctx and ctx.battle) then return out end
  table.insert(out, 1, { label = Strings("SURF & RIDE"), onSelect = function(selected, liveGame)
    mod.exports._closeMountMenus(liveGame)
    for i, partyMon in ipairs(liveGame.save.party or {}) do
      if partyMon == selected then lastWaterMountIndex = i break end
    end
    local liveWorld = mod.exports._mountWorld(liveGame)
    if liveWorld and liveWorld.player.surfing then
      clearWaterRide(liveWorld)
      activateWaterRide(liveGame, selected)
    else
      say(liveGame, "Selected for Surf.\nUse Surf normally.")
    end
  end })
  return out
end, 70)

-- Unified MOUNTS menu ---------------------------------------------------------
local MOUNTS_SCREEN = "DramaticSkyRideMounts"
local function partyName(game, mon, species)
  if mon and mon.nickname and mon.nickname ~= "" then return mon.nickname end
  local def = game.data and game.data.pokemon and game.data.pokemon[mon and mon.species]
  return def and def.name or species or (mon and mon.species) or "POKEMON"
end

if mod.content and mod.content.screens and mod.ui and mod.ui.ListMenu then
  mod.content.screens:register(MOUNTS_SCREEN, {
    new = function(game)
      local items = {}
      if flight.active then items[#items + 1] = { label = "LAND", value = { kind = "land" } } end
      if ground.active then items[#items + 1] = { label = "DISMOUNT", value = { kind = "dismount" } } end
      for i, mon in ipairs(game.save.party or {}) do
        local fs = healthy(mon) and mountSpecies(game, mon) or nil
        local gs = healthy(mon) and groundSpecies(game, mon) or nil
        local ws = healthy(mon) and waterSpecies(game, mon) or nil
        if gs then items[#items + 1] = { label = partyName(game, mon, gs), right = "GROUND",
          value = { kind = "ground", index = i } } end
        if fs then items[#items + 1] = { label = partyName(game, mon, fs), right = "FLY",
          value = { kind = "flight", index = i } } end
        if not flight.active and ws and monKnowsMove(mon, "SURF") then
          items[#items + 1] = { label = partyName(game, mon, ws), right = "SURF",
            value = { kind = "water", index = i } }
        end
      end
      return mod.ui.ListMenu.new(game, "MOUNTS", items, {
        pageJump = true,
        onChoose = function(item, menu)
          local value = item and item.value or {}
          menu:close()
          mod.exports._closeMountMenus(game)
          if value.kind == "land" then beginLanding(game, false)
          elseif value.kind == "dismount" then stopGroundRide(game, "menu")
          elseif value.kind == "ground" then
            lastGroundMountIndex = value.index
            if ground.active then stopGroundRide(game, "switch") end
            startGroundRide(game, game.save.party[value.index])
          elseif value.kind == "flight" then
            if ground.active then stopGroundRide(game, "switch_to_flight") end
            startFlight(game, game.save.party[value.index])
          elseif value.kind == "water" then
            lastWaterMountIndex = value.index
            local world = mod.exports._mountWorld(game)
            if world and world.player.surfing then
              clearWaterRide(world)
              activateWaterRide(game, game.save.party[value.index])
            else
              say(game, "Selected for Surf.\nUse Surf normally.")
            end
          end
        end,
      })
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or mountOption("mount_menu", true) ~= true then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "MOUNTS",
      onSelect = function() mod.ui.push(game, MOUNTS_SCREEN) end,
    })
  end, 75)
end

mod.exports.groundStamina = function() return ground.stamina or 0 end
mod.exports.groundGalloping = function() return ground.gallop == true end
mod.exports.waterMountSpecies = function() return water.species end
mod.exports.isWaterRiding = function() return water.active == true end
mod.exports.waterRideDiagnostics = function()
  return {
    active = water.active == true,
    species = water.species,
    source = water.source,
    lastFailure = water.lastFailure,
    rider = water.riderSprite ~= nil,
  }
end
-- Read-only late-render bridge. Visible Surf deliberately keeps its mutable
-- lifecycle private; Gold's live-player renderer only needs the chosen mount
-- and the already-validated rider pose.
mod.exports._waterRideVisual = function()
  return water.active == true and water.sprite or nil
end
mod.exports._waterRideRiderPose = function(entity)
  if not (water.active and water.riderSprite) then return nil end
  entity.sprite = water.riderSprite
  return waterRiderPose(entity)
end
mod.exports.eligibleWaterMounts = function()
  local out = {}
  for species, cfg in pairs(WATER_ELIGIBLE) do out[#out + 1] = { species = species, dex = cfg.dex } end
  table.sort(out, function(a, b) return a.dex < b.dex end)
  return out
end

log("alpha.15 Ground Ride, visible Surf mounts and mount menu loaded")

end)()
