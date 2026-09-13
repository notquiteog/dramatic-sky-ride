
-- Ground Ride ---------------------------------------------------------------
-- A separate family of terrestrial mounts. Normal world collisions and
-- scripts remain active; only official ledge definitions gain a safe reverse
-- traversal while mounted.
local GROUND_ELIGIBLE = {
  ARCANINE   = { dex = 59,  label = "ARCANINE",   lift = 6.5 },
  RAPIDASH   = { dex = 78,  label = "RAPIDASH",   lift = 7.0 },
  DODRIO     = { dex = 85,  label = "DODRIO",     lift = 7.0 },
  RHYHORN    = { dex = 111, label = "RHYHORN",    lift = 6.0 },
  RHYDON     = { dex = 112, label = "RHYDON",     lift = 7.0 },
  KANGASKHAN = { dex = 115, label = "KANGASKHAN", lift = 7.5 },
  TAUROS     = { dex = 128, label = "TAUROS",     lift = 6.5 },
}
local GROUND_BY_DEX = {}
for species, cfg in pairs(GROUND_ELIGIBLE) do GROUND_BY_DEX[cfg.dex] = species end

local ground = {
  active = false,
  species = nil,
  mon = nil,
  sprite = nil,
  riderSprite = nil,
  riderEntity = nil,
  suspended = nil,
  resumeAfterBattle = nil,
}
local lastGroundMountIndex = nil

local function groundSpecies(game, mon)
  if not (game and mon) then return nil end
  if GROUND_ELIGIBLE[mon.species] then return mon.species end
  local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
  local dex = def and tonumber(def.dex)
  return dex and GROUND_BY_DEX[dex] or nil
end

local function groundAreaAllowed(ow)
  if not (ow and ow.map and ow.map.def) then return false end
  local generation = mod.exports and mod.exports.runtimeGeneration or nil
  if generation and type(generation.isGen2) == "function"
     and generation.isGen2(Game) == true then
    -- Match Gold's Bicycle CheckEnvironment rule. GATE is deliberately
    -- rideable: gatehouses and authored inter-map passages must preserve the
    -- mount, while INDOOR / ENVIRONMENT_5 / DUNGEON destinations remove it.
    local environment = tostring(ow.map.def.environment or ""):upper()
    return environment == "TOWN" or environment == "ROUTE"
      or environment == "CAVE" or environment == "GATE"
  end
  if type(ow.bikeAllowed) == "function" then
    local ok, allowed = pcall(ow.bikeAllowed, ow, ow.map.id)
    if ok then return allowed == true end
  end
  if Map.isOutdoor(ow.map.def) then return true end
  local tileset = tostring(ow.map.def.tileset or ""):upper()
  return tileset == "CAVERN" or tileset == "UNDERGROUND"
end

local function groundFollowerPath(species)
  local cfg = GROUND_ELIGIBLE[species]
  if not cfg or not (love and love.filesystem and love.filesystem.getDirectoryItems) then return nil end
  local filename = string.format("follower_%03d.png", cfg.dex)
  local ok, names = pcall(love.filesystem.getDirectoryItems, "mods")
  if not ok or type(names) ~= "table" then return nil end
  local fallback
  for _, name in ipairs(names) do
    local root = "mods/" .. name
    local asset = root .. "/assets/sprites/" .. filename
    if fileExists(asset) then
      local raw = love.filesystem.read(root .. "/manifest.json")
      local id = manifestId(raw)
      if id and FOLLOWER_IDS[id] then return asset end
      fallback = fallback or asset
    end
  end
  return fallback
end

local function buildGroundMountSprite(species)
  local path = groundFollowerPath(species)
  if not path then return nil, "missing_follower_asset" end
  local okImage, image = pcall(Assets.image, path)
  if not okImage or not image then return nil, "mount_load_failed" end
  setNearest(image)
  local w, h = image:getDimensions()
  if w < 16 or h < 96 then return nil, "unexpected_sheet_size" end
  local def = { id = "GROUND_RIDE_" .. species, image = path,
    frames = 6, walker = true, trueColor = true }
  local sprite = SpriteRenderer.new(def, "ground_ride_" .. species)
  sprite.image = image
  return sprite
end

local function removeGroundRiderEntity(ow)
  local entity = ground.riderEntity
  if not entity then return end
  if ow then
    removeFromList(ow.entities, entity)
    removeFromList(ow.npcs, entity)
  end
  ground.riderEntity = nil
end

local function groundRiderPose(entity)
  local ow = Game.overworld
  local p = ow and ow.player
  if not (ground.active and p and ground.riderSprite) then
    return entity.sprite, entity.px or 0, entity.py or 0, entity.facing or "down", 0, false, false
  end
  local cfg = GROUND_ELIGIBLE[ground.species] or { lift = 6.5 }
  entity.cellX, entity.cellY = p.cellX, p.cellY
  entity.px, entity.py, entity.facing = p.px, p.py, p.facing
  local phase = math.floor((p.animClock or 0) / 16) % 2
  return ground.riderSprite, p.px, p.py - cfg.lift, p.facing, phase, false, false
end

local function groundRiderDraw(entity, camX, camY)
  local sprite, px, py, facing, phase, flip = groundRiderPose(entity)
  if sprite and sprite.draw then sprite:draw(px, py, camX, camY, facing, phase, flip) end
end

local function ensureGroundRiderEntity(ow)
  if not (ground.active and ow and ow.player and ground.riderSprite) or isFirstPerson() then
    removeGroundRiderEntity(ow)
    return nil
  end
  local e = ground.riderEntity
  if not e then
    e = { id = "ground_ride_rider", groundRideRider = true, passable = true,
      sprite = ground.riderSprite, pose = groundRiderPose, draw = groundRiderDraw }
    ground.riderEntity = e
  end
  groundRiderPose(e)
  if not contains(ow.entities, e) then table.insert(ow.entities, e) end
  return e
end

local groundPlayerPose = Player.pose
function Player:pose()
  local sprite, px, py, facing, phase, flip, hopping = groundPlayerPose(self)
  local ow = Game.overworld
  if ground.active and ow and ow.player == self then
    local visual = ground.sprite or sprite
    local walkPhase = math.floor((self.animClock or 0) / 16) % 2
    return visual, self.px, self.py, facing, walkPhase, flip, hopping
  end
  return sprite, px, py, facing, phase, flip, hopping
end

local function stopGroundRide(game, reason, keepFollowers)
  if not ground.active then return false end
  local ow = mod.exports._mountWorld(game)
  removeGroundRiderEntity(ow)
  if not keepFollowers then restoreFollowers(ow) end
  ground.active, ground.species, ground.mon = false, nil, nil
  ground.sprite, ground.riderSprite, ground.suspended = nil, nil, nil
  if reason then log("ground ride ended: %s", reason) end
  return true
end

local function startGroundRide(game, mon)
  local ow = mod.exports._mountWorld(game)
  if not mod.exports._mountFreeRoam(game, ow) then return false end
  if flight.active then notifyHud("LAND FIRST"); feedback("blocked"); return false end
  if ground.active then return true end
  if not groundAreaAllowed(ow) then say(game, "You cannot ride here."); return false end
  if ow.player.surfing then say(game, "Reach land first."); return false end
  if not healthy(mon) then say(game, "It is too tired\nto carry you."); return false end
  local species = groundSpecies(game, mon)
  if not species then return false end
  local sprite, reason = buildGroundMountSprite(species)
  if not sprite then
    mod.log:error("unable to build ground mount %s: %s", tostring(species), tostring(reason))
    say(game, "PokePC follower\nsprites are missing.")
    return false
  end
  if game.save then game.save.onBike = false end
  ground.active, ground.species, ground.mon, ground.sprite = true, species, mon, sprite
  ground.riderSprite = select(1, buildRiderSprite(ow.player))
  ground.suspended = suspendFollowers(ow)
  ensureGroundRiderEntity(ow)
  feedback("takeoff")
  log("ground ride started on %s at %s (%d,%d)", species, ow.map.id, ow.player.cellX, ow.player.cellY)
  return true
end

local function preferredGroundMount(game)
  local party = game and game.save and game.save.party or {}
  if lastGroundMountIndex and healthy(party[lastGroundMountIndex])
     and groundSpecies(game, party[lastGroundMountIndex]) then return party[lastGroundMountIndex] end
  for i, mon in ipairs(party) do
    if healthy(mon) and groundSpecies(game, mon) then lastGroundMountIndex = i; return mon end
  end
  return nil
end

local function useGroundShortcut(game)
  local ow = mod.exports._mountWorld(game)
  if not mod.exports._mountFreeRoam(game, ow) then return false end
  if flight.active then notifyHud("LAND FIRST"); say(game, "Land before changing\nmounts."); return true end
  if ground.active then stopGroundRide(game, "shortcut"); return true end
  if ow.player.surfing then say(game, "Reach land first."); return true end
  local mon = preferredGroundMount(game)
  if not mon then say(game, "No healthy ground\nmount is available."); return true end
  startGroundRide(game, mon)
  return true
end

-- Party menu: terrestrial mounts receive RIDE independently from RIDE & FLY.
mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
  local out = next(game, items, mon, ctx)
  if type(out) ~= "table" then out = items end
  if flight.active or ground.active or (ctx and ctx.battle) then return out end
  if not groundSpecies(game, mon) then return out end
  table.insert(out, 1, { label = Strings("RIDE"), onSelect = function(selected, liveGame)
    mod.exports._closeMountMenus(liveGame)
    for i, partyMon in ipairs(liveGame.save.party or {}) do
      if partyMon == selected then lastGroundMountIndex = i break end
    end
    startGroundRide(liveGame, selected)
  end })
  return out
end, 60)

-- Official ledges only. The native direction runs first. When it rejects the
-- move, Ground Ride recognizes the same authored ledge tile approached from
-- the opposite direction and reuses the engine's two-cell hop animation.
local nativeCheckLedgeHop = OverworldState.checkLedgeHop
function OverworldState:checkLedgeHop(dir)
  if nativeCheckLedgeHop(self, dir) then return true end
  if not (ground.active and Game.overworld == self and self.player and self.map) then return false end
  local opposite = { up = "down", down = "up", left = "right", right = "left" }
  local originalDir = opposite[dir]
  if not originalDir then return false end
  local p, tileset = self.player, self.map.def.tileset
  local fx, fy = Collision.target(p.cellX, p.cellY, dir)
  if not self.map:inBounds(fx, fy) then return false end
  local front = self.map:cellTile(fx, fy)
  local official = false
  for _, ledge in ipairs(Game.data.field.ledges or {}) do
    if (ledge.tileset or "OVERWORLD") == tileset
       and ledge.facing == originalDir and ledge.input == originalDir
       and ledge.ledgeTile == front then official = true; break end
  end
  if not official then return false end
  local lx, ly = Collision.target(fx, fy, dir)
  if not self.map:inBounds(lx, ly) then
    local dest, ts, cx, cy = self:connectionLanding(dir)
    if not (dest and Map.defPassable(dest, ts, cx, cy, false)) then return false end
    require("src.core.Sound").play(Game.data, "Ledge")
    p.hopFrames, p.hopTotal = 32, 32
    self:scriptMove(p, dir, 1, function() self:checkEdgeExit(dir) end)
    return true
  end
  if self.map.isWaterCell and self.map:isWaterCell(lx, ly) then return false end
  if Collision.occupied(self.entities, lx, ly, p) or storyOccupied(self.entities, lx, ly, p) then return false end
  if not self.map:isWalkableCell(lx, ly) then return false end
  require("src.core.Sound").play(Game.data, "Ledge")
  p.hopFrames, p.hopTotal = 32, 32
  self:scriptMove(p, dir, 2)
  return true
end

mod.hooks:wrap("movement.speed", function(next, frames, ctx)
  local value = next(frames, ctx)
  if ground.active then return math.max(4, (tonumber(value) or tonumber(frames) or 16) / 2) end
  return value
end, 85)

-- Wrap the already-installed flight shortcuts. H/X dismount Ground Ride then
-- continue into the existing flight shortcut; G/Y is exclusively terrestrial.
local groundKeypressed = Game.keypressed
function Game:keypressed(key, ...)
  local provider = mod.exports and mod.exports._dramaticProviderState or nil
  local groundKey = provider and provider.id == "DRAMALESS_SHAPE" and "j" or "g"
  if key == groundKey and useGroundShortcut(self) then return end
  if key == "h" and ground.active then stopGroundRide(self, "switch_to_flight") end
  return groundKeypressed(self, key, ...)
end

local groundGamepadpressed = Game.gamepadpressed
function Game:gamepadpressed(joystick, button, ...)
  -- Y toggles Ground Ride in free-roam. X belongs to the flight wrapper below
  -- this one; when already ground-mounted, dismount first and forward X so the
  -- same press can transition directly into flight.
  if button == "y" and useGroundShortcut(self) then return end
  if button == "x" and ground.active then
    stopGroundRide(self, "switch_to_flight")
  end
  return groundGamepadpressed(self, joystick, button, ...)
end

-- Battle Art/Dramatic Shape staged battles snapshot the overworld cast inside
-- OverworldState:pushBattle, before battle.started. DSR loads after either
-- voxel provider, so this wrapper is outermost and removes the Ground Ride
-- rider before that snapshot. The later Lot 1 stopGroundRide wrapper still
-- receives reason="battle", preserving normal post-battle remount behavior.
local groundPushBattle = OverworldState.pushBattle
if type(groundPushBattle) == "function" then
  function OverworldState:pushBattle(battle, ...)
    if ground.active and Game.overworld == self then
      stopGroundRide(Game, "battle", true)
    end
    return groundPushBattle(self, battle, ...)
  end
end

-- Preserve the mount through outdoor/cavern map transitions, but remove it
-- immediately when the destination metadata no longer permits Ground Ride.
local groundSetMap = OverworldState.setMap
function OverworldState:setMap(mapId, x, y, facing, opts, ...)
  local result = groundSetMap(self, mapId, x, y, facing, opts, ...)
  if ground.active then
    if groundAreaAllowed(self) and not self.player.surfing then ensureGroundRiderEntity(self)
    else stopGroundRide(Game, "incompatible_map") end
  end
  return result
end

local groundUpdate = OverworldState.update
function OverworldState:update(dt, ...)
  local result = groundUpdate(self, dt, ...)
  if ground.active and Game.overworld == self then
    -- Gold's native World:takeWarp calls World:setMap directly and therefore
    -- bypasses the Gen 1-compatible setMap facade wrapped above. Re-check the
    -- destination after every native tick so entering a building behaves like
    -- the Bicycle, without treating seamless route/gate connections as doors.
    if not groundAreaAllowed(self) then
      stopGroundRide(Game, "incompatible_map")
    else
      purgeFollowersDuringFlight(self)
      ensureGroundRiderEntity(self)
    end
  elseif ground.resumeAfterBattle and Game.overworld == self
      and Game.stack and Game.stack:top() == self then
    local mon = ground.resumeAfterBattle
    ground.resumeAfterBattle = nil
    if healthy(mon) and groundSpecies(Game, mon) and groundAreaAllowed(self) and not self.player.surfing then
      startGroundRide(Game, mon)
    end
  end
  return result
end

mod.events:on("battle.started", function()
  if ground.active then
    ground.resumeAfterBattle = ground.mon
    stopGroundRide(Game, "battle", true)
  end
end)

mod.exports.isGroundRiding = function() return ground.active end
mod.exports.groundMountSpecies = function() return ground.species end
mod.exports.requestGroundMount = function(mon) return startGroundRide(Game, mon or preferredGroundMount(Game)) end
mod.exports.requestGroundDismount = function() return stopGroundRide(Game, "external") end
mod.exports.canGroundJump = function() return ground.active end
mod.exports.eligibleGroundMounts = function()
  local out = {}
  for species, cfg in pairs(GROUND_ELIGIBLE) do out[#out + 1] = { species = species, dex = cfg.dex } end
  table.sort(out, function(a, b) return a.dex < b.dex end)
  return out
end

log("Ground Ride alpha.14 integration loaded")
