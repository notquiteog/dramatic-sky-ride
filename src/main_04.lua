      local asset = root .. "/assets/sprites/" .. filename
      if fileExists(asset) then
        local raw = love.filesystem.read(root .. "/manifest.json")
        local id = manifestId(raw)
        if id and FOLLOWER_IDS[id] then return asset end
        fallback = fallback or asset
      end
    end
    if fallback then return fallback end
  end

  local candidates = {
    "mods/pokepcfollowers/assets/sprites/",
    "mods/PokePCFollowers/assets/sprites/",
    "mods/PokePCFollowers_VoxelMerge/assets/sprites/",
  }
  for _, root in ipairs(candidates) do
    local asset = root .. filename
    if fileExists(asset) then return asset end
  end
  return nil
end

-- Load only the selected voxel provider's public library. Battle Art Voxel
-- Fork remains the preferred provider. Dramaless Shape is a supported
-- alternative provider, and the retired upstream Dramatic Shape id remains a
-- best-effort fallback for existing manual installs.
-- Provider detection stays inside this already-existing function so the huge
-- concatenated DSR chunk does not gain more top-level locals.
local dramaticTileShape = nil
local dramaticTileShapeTried = false
local dramaticRoot = nil
local dramaticData = {}

local dramaticLib = nil
local dramaticFirstPerson = nil
local dramaticFreeMove = nil

local function loadDramaticLib()
  if dramaticLib then return dramaticLib end
  if not mod.find then return nil end

  local okBattleArt, battleArt = pcall(mod.find, mod, "BATTLE_ART_VOXEL_FORK")
  local okDramaless, dramaless = pcall(mod.find, mod, "DRAMALESS_SHAPE")
  local okUpstream, upstream = pcall(mod.find, mod, "DRAMATIC_SHAPE")
  battleArt = okBattleArt and battleArt or nil
  dramaless = okDramaless and dramaless or nil
  upstream = okUpstream and upstream or nil
  local handle = battleArt or dramaless or upstream
  local exports = handle and handle.exports or nil
  local pipelines = exports and exports.pipelines or nil
  -- Current Battle Art and Dramaless releases both register the canonical
  -- "voxel" render pipeline. Respect an explicit provider export if one is
  -- added later, otherwise use that canonical id for every supported provider.
  local voxelPipeline = pipelines and pipelines.voxel or "voxel"

  mod.exports._dramaticProviderState = {
    upstream = upstream,
    battleArt = battleArt,
    dramaless = dramaless,
    conflict = ((battleArt and dramaless) or (battleArt and upstream)
      or (dramaless and upstream)) ~= nil,
    handle = handle,
    id = handle and handle.id or nil,
    version = handle and (handle.version or (exports and exports.version)) or nil,
    voxelPipeline = voxelPipeline,
    primary = battleArt ~= nil and handle == battleArt,
  }

  if handle then
    local okLevel, currentLevel = pcall(Pipelines.level, voxelPipeline)
    log("Voxel provider: %s %s / pipeline: %s / level: %s",
      tostring(handle.id),
      tostring(handle.version or (exports and exports.version) or "unknown"),
      tostring(voxelPipeline),
      tostring(okLevel and (tonumber(currentLevel) or 0) or "unavailable"))
  end

  local lib = exports and exports.lib or nil
  if type(lib) ~= "table" or type(lib.require) ~= "function" then return nil end
  dramaticLib = lib
  return lib
end

local function dramaticModule(name)
  local lib = loadDramaticLib()
  if not lib then return nil end
  local ok, value = pcall(lib.require, name)
  return ok and value or nil
end

local function findDramaticRoot()
  if dramaticRoot then return dramaticRoot end
  if not (love and love.filesystem and love.filesystem.getDirectoryItems) then
    return nil
  end
  if not mod.exports._dramaticProviderState then loadDramaticLib() end
  local state = mod.exports._dramaticProviderState or {}
  local targetId = state.id
  if not targetId then return nil end
  local ok, names = pcall(love.filesystem.getDirectoryItems, "mods")
  if not ok or type(names) ~= "table" then return nil end
  for _, name in ipairs(names) do
    local root = "mods/" .. name
    local raw = love.filesystem.read(root .. "/manifest.json")
    if manifestId(raw) == targetId then
      dramaticRoot = root
      return root
    end
  end
  return nil
end

local function loadDramaticTileShape()
  if dramaticTileShapeTried then return dramaticTileShape end
  dramaticTileShapeTried = true

  -- Supported voxel providers expose their companion API through exports.lib.
  -- Prefer that public seam: it works whether the provider was installed
  -- unpacked or imported as a mounted ZIP by Gen1Recomp's Mod Manager.
  local exported = dramaticModule("TileShape")
  if type(exported) == "table" and type(exported.forMap) == "function" then
    dramaticTileShape = exported
    return exported
  end

  -- Compatibility fallback for an unpacked provider whose public library is
  -- unavailable. Current supported releases should normally never need this.
  local root = findDramaticRoot()
  if not root then
    mod.log:warn("voxel provider TileShape API unavailable; terrain height compensation disabled")
    return nil
  end

  local V = {}
  function V.data(name)
    if dramaticData[name] ~= nil then return dramaticData[name] end
    local rel = root .. "/data/" .. name .. ".lua"
    local source = love.filesystem.read(rel)
    if not source then error("missing voxel provider data file: " .. rel, 0) end
    local chunk, err = load(source, "@" .. rel)
    if not chunk then error(err, 0) end
    local value = chunk(V)
    dramaticData[name] = value
    return value
  end

  local rel = root .. "/lib/TileShape.lua"
  local source = love.filesystem.read(rel)
  if not source then
    mod.log:warn("voxel provider TileShape.lua is missing")
    return nil
  end
  local chunk, err = load(source, "@" .. rel)
  if not chunk then
    mod.log:warn("voxel provider TileShape.lua did not compile: %s", tostring(err))
    return nil
  end
  local ok, module = pcall(chunk, V)
  if not ok or type(module) ~= "table" then
    mod.log:warn("unable to load voxel provider TileShape: %s", tostring(module))
    return nil
  end
  dramaticTileShape = module
  return module
end

local function terrainGroundHeight(map, cx, cy)
  if not (map and map.inBounds and map:inBounds(cx, cy)) then return 0 end
  local TileShape = loadDramaticTileShape()
  if not TileShape then return 0 end
  local ok, height = pcall(function()
    local shapes = TileShape.forMap(map)
    local s = shapes and shapes[map:cellTile(cx, cy)]
    if not s or s.art == "stair" then return 0 end
    return math.max(0, tonumber(s.h) or 0)
  end)
  return ok and height or 0
end

local function tallBuildingMinimum(ow)
  local map = ow and ow.map
  local p = ow and ow.player
  if not (map and map.def and p) then return 0 end
  local best = 0
  for _, warp in ipairs(map.def.warps or {}) do
    local spec = tallSpecForDestination(warp.destMap)
    if spec then
      local x0, x1 = warp.x - spec.left, warp.x + spec.right
      local y0, y1 = warp.y - spec.back, warp.y + spec.front
      if p.cellX >= x0 and p.cellX <= x1
         and p.cellY >= y0 and p.cellY <= y1 then
        best = math.max(best, spec.height)
      end
    end
  end
  return best
end

local function safetyMinimum(ow)
  local map = ow and ow.map
  local p = ow and ow.player
  if not (map and p) then return 0 end
  -- At normal cruise height a 32px cliff still fits underneath, so ordinary
  -- relief remains visually stable. Only deliberately low flight needs this
  -- terrain floor; landmark buildings retain their authored larger minimum.
  local terrain = 0
  -- One-cell look-ahead in every direction gives the safety climb time to