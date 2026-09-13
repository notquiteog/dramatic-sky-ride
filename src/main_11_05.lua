  local result = update(self, dt, ...)
  -- Companion mods may respawn their entities during a seamless map change
  -- or their own update hook. Purging after the normal world update ensures
  -- none of those ground followers reaches the render pass while airborne.
  if flight.active and Game.overworld == self then
    purgeFollowersDuringFlight(self)
    if showRiderEnabled() then
      ensureRiderEntity(self)
    else
      removeRiderEntity(self)
    end
    ensureGroundFxEntity(self)
  elseif pendingFollowerRestore and Game.overworld == self then
    pendingFollowerRestore.frames = pendingFollowerRestore.frames - 1
