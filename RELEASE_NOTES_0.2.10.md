## Dramatic Sky Ride 0.2.10

This release stabilizes Generation II mount presentation across native HGSS/PokeMMO sprites, classic 2D cards and Stadium/voxel rendering.

### Fixed / Compatibility

- Added the native HGSS/PokeMMO 4x4 atlas path to Visible Surf in Generation II while preserving the classic 16x96 fallback.
- Kept the same native HGSS/PokeMMO source, crop and Pokédex scaling across Flight, Ground Ride and Visible Surf when the embedded Gen2 Wilds provider is active.
- Fixed Gold 2D rider/mount separation over raised terrain by making both cards use the same provider-relative height reference.
- Reduced Gyarados only in the classic 2D renderer; its HGSS/PokeMMO size is unchanged.
- Corrected Stadium 3D flight saddle alignment after model scaling, including large flyers such as Ho-Oh and Lugia, without per-species trim hacks.
- Preserved existing fallbacks, Surf lifecycle, camera behavior and non-mounted companion rendering.

### Companion projects

- Wilds of Kanto: https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod
- PokéPC Followers: https://github.com/mfrtechconsult/PokePCFollowers
- Wild Skies: https://github.com/ShaneHudson/gen1recomp-mods/tree/main/wild_skies
- Battle Art Voxel Fork: https://github.com/absol89/DramaticShapeVoxelMod
- Dramaless Shape: https://github.com/artyrambles/DRAMALESS_SHAPE
- Crystal 251: https://github.com/Deftones565/gen1recomp-mod-crystal-251
- Gen2-3D-Sprites by Randy: https://github.com/randyadr/Gen2-3D-Sprites/

The attached ZIP is launcher-ready and is reconstructed and compiled with LuaJIT after packaging before publication.
