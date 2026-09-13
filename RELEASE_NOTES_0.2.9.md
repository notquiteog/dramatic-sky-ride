## Dramatic Sky Ride 0.2.9

This release expands Dramatic Sky Ride's Generation II presentation support and hardens compatibility with voxel/Stadium companion mods.

### Added

- Added optional Generation II voxel/Stadium mount interoperability with `randyadr/Gen2-3D-Sprites` (`STADIUM2_OVERWORLD_MODELS`).
- Flight, Ground Ride and Visible Surf can now publish a dedicated visual mount entity to the Gen2 voxel pipeline while DSR remains authoritative for gameplay.
- Preserved existing extra-entity providers so companion systems such as Wilds can continue to render alongside DSR.
- Added provider arbitration and single-owner guards so Randy's Gen2 renderer takes priority when available without double-rendering DSR's native Stadium 2 path.
- Added diagnostics and compatibility contracts for the Gen2 voxel bridge.

### Fixed / Compatibility

- Kept the Gold player as the rider actor while the mounted Pokémon is rendered separately, improving compatibility with 3D player replacements and first/third-person camera modes.
- Added safe fallback behavior when Stadium 3D is disabled, a model is missing, or the Gen2 voxel provider is unavailable.
- Completely retired DSR's synthetic flight ground-FX entity in both Generation I and Generation II. The landing marker and its shared dynamic shadow are no longer created, preventing voxel renderers from interpreting that helper entity as a giant overworld sprite.
- Removed the obsolete `LANDING MARKER` and `DYNAMIC SHADOW` settings while retaining cleanup for stale helper entities after a hot reload.

### Companion projects

- PokéPC Followers: https://github.com/mfrtechconsult/PokePCFollowers
- Gen2-3D-Sprites by Randy: https://github.com/randyadr/Gen2-3D-Sprites/

The attached ZIP is launcher-ready and is reconstructed and compiled with LuaJIT after packaging before publication.
