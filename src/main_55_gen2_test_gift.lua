;(function()
-- Temporary Gold test helper.  It deliberately stays runtime-only: no map
-- object or claimed gift flag is serialized, and the entire layer is skipped
-- by Gen 1.  Remove this part once the Gen 2 mount test pass is complete.

local generation = mod.exports.runtimeGeneration or {}
local isGen2Runtime = generation.isGen2 or function() return false end
if not isGen2Runtime(Game) then return end

local MAP_ID = "NEW_BARK_TOWN"
local NPC_NAME = "DSR_GEN2_TEST_GIVER"
local COMMAND_ID = mod.id .. ":gen2_test_mount_gift"
local GIFT_LEVEL = 50
local GIFTS = {
  { species = "HO_OH", requiredMove = "FLY" },
  { species = "SUICUNE", requiredMove = "SURF" },
  { species = "RAIKOU" },
  { species = "GYARADOS", requiredMove = "SURF" },
}

local function show(ctx, body)
  local vm = ctx and ctx.vm
  if vm and type(vm.showRaw) == "function" then vm:showRaw(body) end
end

local function ownsSpecies(save, species)
  for _, mon in ipairs((save and save.party) or {}) do
    if mon.species == species then return true end
  end
  for _, box in pairs((save and save.boxes) or {}) do
    if type(box) == "table" then
      for _, mon in ipairs(box) do
        if mon.species == species then return true end
      end
    end
  end
  return false
end

local function moveEntry(data, moveId)
  local def = data and data.moves and data.moves[moveId]
  return {
    id = moveId,
    pp = (def and def.pp) or 0,
    maxPp = (def and def.pp) or 0,
  }
end

local function ensureMove(mon, data, moveId)
  if not moveId then return end
  mon.moves = mon.moves or {}
  for _, move in ipairs(mon.moves) do
    if move.id == moveId then return end
  end
  local entry = moveEntry(data, moveId)
  if #mon.moves < 4 then
    mon.moves[#mon.moves + 1] = entry
  else
    -- Slot one is the oldest level-up move.  Replacing it mirrors the normal
    -- four-move rollover and preserves each mount's strongest recent moves.
    mon.moves[1] = entry
  end
end

local function storageRoom(save, boxes, count)
  local party = save.party or {}
  local room = math.max(0, boxes.PARTY_SIZE - #party)
  for index = 1, boxes.NUM_BOXES do
    local box = save.boxes and save.boxes[index]
    room = room + math.max(0, boxes.MONS_PER_BOX
      - (type(box) == "table" and #box or 0))
    if room >= count then return true end
  end
  return room >= count
end

local function firstBoxWithRoom(save, boxes)
  local first = math.max(1, math.min(boxes.NUM_BOXES,
    tonumber(save.currentBox) or 1))
  for offset = 0, boxes.NUM_BOXES - 1 do
    local index = ((first - 1 + offset) % boxes.NUM_BOXES) + 1
    if not boxes.isFull(save, index) then return index end
  end
  return nil
end

local function registerCaught(save, mon)
  save.pokedex = save.pokedex or {}
  save.pokedex.seen = save.pokedex.seen or {}
  save.pokedex.caught = save.pokedex.caught or {}
  save.pokedex.seen[mon.species] = true
  save.pokedex.caught[mon.species] = true
end

local function giveTestMounts(ctx)
  local game = Game
  local save, data = game and game.save, game and game.data
  if not (save and data) then
    show(ctx, "The test mounts are\nnot available yet.")
    return
  end

  local missing = {}
  for _, gift in ipairs(GIFTS) do
    if not ownsSpecies(save, gift.species) then missing[#missing + 1] = gift end
  end
  if #missing == 0 then
    show(ctx, "You already have all\nfour test mounts.")
    return
  end

  local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
  local okBoxes, Boxes = pcall(require, "src.core.gen2.Boxes")
  if not (okMon and okBoxes and Mon and Boxes) then
    show(ctx, "The Gold test helper\ncould not start.")
    return
  end

  save.party = save.party or {}
  save.boxes = save.boxes or {}
  if not storageRoom(save, Boxes, #missing) then
    show(ctx, "There is no room in\nyour PARTY or PC.")
    return
  end

  -- Build the complete batch before touching the save, so an unavailable
  -- species can never leave a partially granted test set behind.
  local built = {}
  for _, gift in ipairs(missing) do
    local mon = Mon.new(data, gift.species, GIFT_LEVEL, { happiness = 120 })
    if not mon then
      show(ctx, "One of the test mounts\nis unavailable.")
      return
    end
    ensureMove(mon, data, gift.requiredMove)
    Mon.stampOT(save, mon)
    built[#built + 1] = mon
  end

  local partyAdded, boxed = 0, 0
  for _, mon in ipairs(built) do
    if #save.party < Boxes.PARTY_SIZE then
      save.party[#save.party + 1] = mon
      partyAdded = partyAdded + 1
    else
      local boxIndex = firstBoxWithRoom(save, Boxes)
      local box = boxIndex and Boxes.box(save, boxIndex)
      if not box then
        -- storageRoom proved this cannot occur; keep the defensive branch from
        -- corrupting a save if another mod changes box capacity mid-command.
        show(ctx, "The PC changed while\ngiving the test mounts.")
        return
      end
      box[#box + 1] = mon
      boxed = boxed + 1
    end
    registerCaught(save, mon)
  end

  if boxed > 0 then
    show(ctx, string.format(
      "%d test mounts received!\n%d joined the PARTY.\n%d went to the PC.\nFLY and SURF are ready.",
      #built, partyAdded, boxed))
  else
    show(ctx, string.format(
      "%d test mounts received!\nFLY and SURF are ready.", #built))
  end
end

local commands = mod.content and mod.content.commands
if not (commands and type(commands.register) == "function") then
  log("Gold test giver skipped: commands registry unavailable")
  return
end
commands:register(COMMAND_ID, giveTestMounts)

local function ensureTestNpc(mapId)
  if mapId ~= MAP_ID then return end
  local api = mod.world
  local world = api and api.overworld and api:overworld()
  local mapDef = world and world.maps and world.maps[MAP_ID]
  if not mapDef then return end

  for _, obj in ipairs(mapDef.objects or {}) do
    if obj.name == NPC_NAME and obj.owner == mod.id then return end
  end

  local npcId, err = api:spawnNpc(MAP_ID, {
    name = NPC_NAME,
    sprite = "SPRITE_SCIENTIST",
    x = 9,
    y = 10,
    movement = 6, -- SPRITEMOVEDATA_STANDING_DOWN
    radius = { x = 0, y = 0 },
    hours = { -1, -1 },
    palette = 0,
    sight = 0,
    type = 0,
    scriptKey = {
      { op = "faceplayer" },
      { op = "modcommand", verb = COMMAND_ID, args = {} },
      { op = "end" },
    },
  })
  if npcId then
    log("temporary Gen 2 test giver spawned in New Bark Town")
  elseif err then
    log("Gold test giver spawn failed: %s", tostring(err))
  end
end

mod.events:on("map.entered", function(ev)
  ensureTestNpc(ev and ev.mapId)
end)

-- A hot reload can happen while New Bark Town is already active and therefore
-- has no fresh map.entered event to trigger.  game.ready is harmless on normal
-- boot (there is no world yet) and covers that development case.
mod.events:on("game.ready", function(ev)
  local game = (ev and ev.game) or Game
  local mapId = game and game.world and game.world.map and game.world.map.id
  ensureTestNpc(mapId)
end)

log("temporary New Bark Town Gen 2 mount giver loaded")
end)();
