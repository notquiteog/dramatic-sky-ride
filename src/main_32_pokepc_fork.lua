;(function()
-- -------------------------------------------------------------------------
-- Maintained PokéPC compatibility fork identity.
--
-- mfrtechconsult/PokePCFollowers deliberately keeps the upstream mod id for
-- save/install compatibility. Detect the maintained fork through its public
-- providerRepository metadata while retaining the shared mod id as a legacy
-- fallback so existing installations do not suddenly stop working.
-- -------------------------------------------------------------------------
local POKEPC_MOD_ID = "PokePCFollowers_VoxelMerge"
local POKEPC_FORK_REPOSITORY = "mfrtechconsult/PokePCFollowers"

local function pokePcHandle()
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, POKEPC_MOD_ID)
  return ok and handle or nil
end

local function providerRepository()
  local handle = pokePcHandle()
  local ex = handle and handle.exports or nil
  return ex and ex.providerRepository or nil
end

local function maintainedForkInstalled()
  return providerRepository() == POKEPC_FORK_REPOSITORY
end

local function compatibleProviderInstalled()
  local handle = pokePcHandle()
  local ex = handle and handle.exports or nil
  return ex ~= nil and (type(ex.resolveFollowerSprite) == "function"
    or type(ex.assetPath) == "function")
end

mod.exports.pokePcCompatibility = {
  modId = POKEPC_MOD_ID,
  preferredRepository = POKEPC_FORK_REPOSITORY,
  installedRepository = providerRepository,
  maintainedForkInstalled = maintainedForkInstalled,
  compatibleProviderInstalled = compatibleProviderInstalled,
}

mod.events:on("mods.loaded", function()
  local handle = pokePcHandle()
  if not handle then return end
  if maintainedForkInstalled() then
    log("PokéPC provider: %s (preferred compatibility fork)", POKEPC_FORK_REPOSITORY)
  elseif compatibleProviderInstalled() then
    log("PokéPC provider uses shared legacy id; maintained fork recommended: %s",
      POKEPC_FORK_REPOSITORY)
  end
end)
end)();
