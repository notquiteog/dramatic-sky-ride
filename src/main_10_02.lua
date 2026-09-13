  end
  if not isOutdoor(ow) then
    say(game, "You can only take\noff outdoors.")
    return false
  end
  if game.save.onBike then
    say(game, "Dismount first.")
    return false
  end
  local wasSurfing = ow.player.surfing == true
  if not healthy(mon) then
    say(game, "It is too tired\nto fly.")
    return false
  end
  local species = mountSpecies(game, mon)
  local cfg = species and ELIGIBLE[species]
  if not cfg then return false end

  local sprite, reason = buildMountSprite(species)
  if not sprite then
    mod.log:error("unable to build %s mount sprite: %s",
                  tostring(species or mon.species), tostring(reason))
    say(game, "Follower sprites\nare missing.")
    return false
  end

  -- 2D is a first-class flight renderer. A voxel provider is optional and,
  -- when enabled, consumes the same flight state through Player:pose().
  -- Taking off from water is the reverse of a water landing: leave the
  -- native surf state first, then let Sky Ride own movement and collision.
  -- This is done only after the mount sprite has loaded successfully, so a
  -- failed takeoff never strands the player on water without surfing.
  if wasSurfing then setSurfingState(ow, false) end

