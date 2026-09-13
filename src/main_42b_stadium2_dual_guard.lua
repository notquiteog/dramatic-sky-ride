(function()
-- -------------------------------------------------------------------------
-- Require both native safety hooks before Stadium 2 may claim readiness.
-- main_42 patches the mount substitution path and the per-update pose path;
-- a partial install is not good enough because one path could then bypass the
-- pack/model validation performed by hardenedEnsureRuntime.
-- -------------------------------------------------------------------------

local function findUpvalue(fn, wanted)
  if type(fn) ~= "function" or not (debug and debug.getupvalue) then return nil end
  for index = 1, 96 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return value end
  end
  return nil
end

local playerEnsure = findUpvalue(Player and Player.pose, "ensureRuntime")
local updateEnsure = findUpvalue(OverworldState and OverworldState.update, "ensureRuntime")
local dual = type(playerEnsure) == "function" and playerEnsure == updateEnsure

local native = mod.exports and mod.exports.stadium3DNative or nil
local hardening = mod.exports and mod.exports.stadium3DHardening or nil
if hardening then
  hardening.playerEnsurePatched = type(playerEnsure) == "function"
  hardening.updateEnsurePatched = type(updateEnsure) == "function"
  hardening.dualEnsurePatched = dual
  hardening.ensurePatched = hardening.ensurePatched == true and dual
end

if native then
  local previousInstalled = native.installed
  if type(previousInstalled) == "function" then
    native.installed = function(...)
      if not dual then return false end
      local ok, value = pcall(previousInstalled, ...)
      return ok and value == true
    end
  end

  local previousStatus = native.cacheStatus
  if type(previousStatus) == "function" then
    native.cacheStatus = function(...)
      local ok, status = pcall(previousStatus, ...)
      status = ok and type(status) == "table" and status or {}
      status.dualEnsurePatched = dual
      if status.operational ~= nil then
        status.operational = status.operational == true and dual
      end
      return status
    end
  end
end

if not dual and mod.log and mod.log.warn then
  pcall(mod.log.warn, mod.log,
    "Stadium 2 native renderer disabled: Player.pose and Overworld.update safety hooks are not both installed")
else
  log("Stadium 2 dual safety guard loaded")
end
end)();
