;(function()
-- Gen1Recomp++ / Gold runtime bridge.
--
-- DSR historically encoded the Gen 1 field-move progression directly in
-- main_22_flight_rules.lua. Gold intentionally keeps the same public mod API,
-- but its save shape and badge gates differ. Keep the mature Gen 1 rules
-- untouched and suppress only the generation-specific checks while Gold is
-- active; main_22b_gen2_progression.lua reinstates the correct Gold rules.
--
-- This file deliberately does NOT opt the manifest into Gen 2 yet. Declaring
-- games=["gen1","gen2"] is the final step after gen2check and real Gold boot
-- validation, per the upstream migration guide.

local baseOptionValue = optionValue

local function isGen2Runtime(game)
  if not game then return false end

  -- Game's Gen2Compat facade forwards unknown data members to Game2.data, so
  -- these native Gen 2 registries are the strongest non-version-string signal.
  local data = game.data
  if data and (data.gen2Maps ~= nil or data.gen2Sprites ~= nil
      or data.gen2Tilesets ~= nil) then
    return true
  end

  -- Fallback once a save exists. Gold owns badges below save.player whereas
  -- Gen 1 keeps its field-move badges in the inventory table.
  local save = game.save
  return save ~= nil
    and type(save.player) == "table"
    and type(save.player.badges) == "table"
end

-- Expose one generation test for every later DSR compatibility layer. Keeping
-- this inside the mod prevents each optional integration from inventing its own
-- heuristic as Gen1Recomp++ evolves.
mod.exports.runtimeGeneration = mod.exports.runtimeGeneration or {}
mod.exports.runtimeGeneration.isGen2 = isGen2Runtime
mod.exports.runtimeGeneration.isGen1 = function(game)
  return not isGen2Runtime(game or Game)
end

-- Preserve access to the user's actual setting. main_22's helpers call the
-- shared optionValue() function, so on Gold we can bypass only the three Gen 1
-- implementations that would otherwise look for THUNDERBADGE/SOULBADGE,
-- Game.data.field and the Gen 1 pokemon learnset table.
mod.exports.runtimeGeneration.rawOptionValue = baseOptionValue

optionValue = function(key, default)
  if isGen2Runtime(Game) then
    if key == "badge_checks" or key == "story_gates"
       or key == "require_fly_move" then
      return false
    end
  end
  return baseOptionValue(key, default)
end

log("Gen1Recomp++ runtime generation bridge loaded")
end)();
