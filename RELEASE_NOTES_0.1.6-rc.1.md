## Dramatic Sky Ride 0.1.6-rc.1

This is a **compatibility preview release** built from the `compat/wilds-of-kanto` development branch. It is intended for testing the next Dramatic Sky Ride ecosystem update before the changes are promoted to `main`.

### Wilds of Kanto integration

- Wilds of Kanto (`overworld_wild_spawns`) can act as an authoritative follower/sprite provider for DSR.
- PokéPC Followers is no longer a hard manifest dependency on this branch when another compatible provider is available.
- DSR can reuse Wilds-compatible walking sheets while preserving its existing mount sizing, rider and voxel rendering paths.
- Added cooperative update-hook protection so Wilds, DSR and other compatible overworld mods can rebuild their wrapper chains without silently removing one another.
- Added compatibility smoke tests for the Wilds/DSR/Deep Dive/Kanto Dive stack and both supported voxel providers.

### Pokémon Stadium Overworld Models compatibility

A small read-only public flight API is now exposed for `STADIUM_OVERWORLD_MODELS` and other ecosystem mods:

- `isFlying()`
- `currentAltitude()`
- `mountSpecies()`
- `stadiumCompatibility`

This lets compatible renderers identify the active flying mount and place the corresponding Pokémon model at the correct airborne altitude without taking ownership of DSR's movement logic.

`currentLift()` is intentionally not faked in this preview; the Stadium integration already treats it as optional and an incorrect value would be worse than no value.

### Flying Music compatibility

A new optional **FLYING MUSIC** setting is included.

`None` remains the default and leaves normal map music unchanged.

When compatible DarioMelo Gen1Recomp music packs are installed, DSR detects them and reuses their existing OGG assets directly:

- `Music_FRLG` — FRLG Surf / Bike
- `Music_HGSS` — HGSS Surf / Bike
- `Music_LGPE` — LGPE Surf / Bike

DSR does **not** copy or redistribute third-party music. The original pack stays installed separately and owns its audio files.

Battle themes, victory cues, jingles and other higher-priority music remain authoritative. Landing restores the normal map or Surf music.

A local `audio/flying/tracks.lua` catalog is also available for future redistributable or user-supplied flight tracks.

### Existing DSR features retained

- Flight, Ground Ride and visible Surf remain available.
- Battle Art Voxel Fork `>=1.7.6 <2.0.0` remains supported and preferred when multiple voxel providers are present.
- Dramaless Shape `>=1.6.4 <2.0.0` remains supported through the canonical `voxel` pipeline, with `st_voxel` retained only as a legacy fallback.
- Wild Skies `>=1.4.1 <2.0.0` remains strongly recommended for the airborne encounter ecosystem.
- `free_fly` remains a conflicting alternative flight engine.

### Testing note

This is an **RC / preview build**, not the next stable release. It is being published from the compatibility branch specifically so the combined Wilds of Kanto, Stadium 3D and music-mod integrations can be tested before merge.

Please report the Gen1Recomp version, voxel provider/version, follower or Wilds setup, Stadium mod version if used, music pack/version if used, mount species, camera mode and exact reproduction steps with any issue.

The attached ZIP is launcher-ready and is rebuilt and LuaJIT-compiled from the exact packaged contents before publication.
