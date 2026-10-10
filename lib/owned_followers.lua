-- Owned fallback art: preserve alpha when native Gen1 palettes recolor HGSS.
return function(mod, Assets, Game)
local ownedFollowerPaths, ownedData = {}, {}
local baseImageData = Assets.imageData
Assets.imageData = function(path)
  local row = ownedData[path]
  if not row then return baseImageData(path) end
  if not row.data then
    local data = love.image.newImageData(love.filesystem.newFileData(row.bytes, "mount.png"))
    -- Native Gen1 OBJ recoloring expects grayscale art, with white reserved
    -- for transparency. Red/orange HGSS pixels otherwise become invisible.
    data:mapPixel(function(_, _, r, g, b, a)
      if a == 0 then return 1, 1, 1, 0 end
      local l = .2126*r + .7152*g + .0722*b
      local shade = l < .28 and 0 or l < .58 and .33 or .66
      return shade, shade, shade, a
    end)
    row.data = data
  end
  return row.data:clone()
end
local function resolve(species, cfg)
  if ownedFollowerPaths[species] ~= nil then return ownedFollowerPaths[species] or nil end
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[species]
  local dex = tonumber(cfg and cfg.dex or def and def.dex)
  local relative = dex and string.format("assets/hgss/%d-normal-6.png", dex)
  local bytes = relative and mod:read(relative)
  local path = bytes and mod.assets and mod.assets.path and mod.assets:path(relative)
  if path then ownedData[path] = { bytes = bytes } end
  ownedFollowerPaths[species] = path or false
  return path
end
return resolve
end
