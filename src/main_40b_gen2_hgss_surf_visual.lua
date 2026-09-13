;(function()
local previousWaterVisual = mod.exports and mod.exports._waterRideVisual or nil
if type(previousWaterVisual) ~= "function" then return end

local function currentWaterSpecies()
  local active = mod.exports and mod.exports.isWaterRiding or nil
  local species = mod.exports and mod.exports.waterMountSpecies or nil
  if not (type(active) == "function" and type(species) == "function") then return nil end
  local okActive, yes = pcall(active)
  if not (okActive and yes == true) then return nil end
  local okSpecies, value = pcall(species)
  return okSpecies and value or nil
end

local function resolveHgss(species)
  if not species then return nil end
  local native = mod.exports and mod.exports.nativePokeMMOMounts or nil
  if native and type(native.resolve) == "function" then
    local ok, renderer = pcall(native.resolve, species)
    if ok and renderer then return renderer end
  end
  local embedded = mod.exports and mod.exports.gen2EmbeddedPokeMMOMounts or nil
  if embedded and type(embedded.resolve) == "function" then
    local ok, renderer = pcall(embedded.resolve, species)
    if ok and renderer then return renderer end
  end
  return nil
end

mod.exports._waterRideVisual = function(...)
  local species = currentWaterSpecies()
  local renderer = species and resolveHgss(species) or nil
  if renderer then return renderer end
  return previousWaterVisual(...)
end

mod.exports.gen2HgssSurfVisual = {
  api = 1,
  active = function()
    local species = currentWaterSpecies()
    return species ~= nil and resolveHgss(species) ~= nil
  end,
}

log("Visible Surf HGSS/PokeMMO visual bridge loaded")
end)();
