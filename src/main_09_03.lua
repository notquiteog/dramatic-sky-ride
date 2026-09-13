-- may touch down on water and immediately continue in the engine's surfing
-- state. Gen 1 also permits field moves from a fainted party member, so HP is
-- not part of this check.
local function partyMonKnowsMove(game, moveId)
  local party = game and game.save and game.save.party or {}
  for _, mon in ipairs(party) do
    for _, move in ipairs(mon.moves or {}) do
      local id = type(move) == "table" and move.id or move
      if id == moveId then return mon end
    end
  end
  return nil
end

local function isPikachu(game, mon)
  if not (game and mon) then return false end
  if mon.species == "PIKACHU" then return true end
  local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
  return def and tonumber(def.dex) == 25 or false
end

-- Enter or leave the native surfing state without replaying the normal party
-- menu text/white flash. The Sky Ride landing animation is already the visual
-- transition, and restoring followers after this call lets companion mods see
-- the correct water state immediately.
local function setSurfingState(ow, enabled, surfMon)
  local p = ow and ow.player
  if not p then return false end
  enabled = enabled == true
