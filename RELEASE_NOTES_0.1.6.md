# Dramatic Sky Ride 0.1.6

Dramatic Sky Ride 0.1.6 is a major feature and compatibility release over 0.1.5.

## Highlights

- Native 2D flight is now available without requiring a voxel provider.
- Wilds of Kanto or PokéPC Followers can provide mount sprites; PokéPC is no longer a hard requirement.
- The maintained `mfrtechconsult/PokePCFollowers` fork is the preferred PokéPC compatibility target.
- Added Generation II mounts through National Pokédex data, without requiring Crystal 251 by mod id.
- Added Generation II flying mounts: Noctowl, Crobat, Xatu, Skarmory, Lugia and Ho-Oh.
- Added Generation II Ground Ride mounts: Meganium, Girafarig, Ursaring, Donphan, Stantler, Raikou, Entei, Suicune and Tyranitar.
- Added Generation II Visible Surf mounts: Feraligatr, Mantine, Kingdra and Lugia.
- Suicune is the unique amphibious Ground Ride mount and can run seamlessly from land to water and back once normal Surf progression is unlocked.
- Added per-species Gen II Ground Ride speed/gallop profiles and Pokédex-proportional size controls.
- Added a public airborne sprite-source API so compatible mods can provide animated 2D mount art.
- Added optional Flying Music using already-installed FRLG, HGSS or LGPE music packs without redistributing their audio.
- Added cooperative update-hook protection for Wilds of Kanto and companion-mod stacks, preventing displaced overworld wrappers from softlocking active mounts.
- Improved Battle Art and Dramaless interoperability while keeping native 2D flight independent of either voxel provider.
- Followers are hidden by default while mounted. When `GROUND FOLLOWERS` is enabled, followers are intended to remain available on land Ground Ride only; they stay hidden during Flight and Surf.
- Improved Gen II mount facing in 1ST/3RD camera modes and Suicune continuity across map connections and water battles.
- Added dedicated CI for native 2D loading, Wilds compatibility, Gen II mount contracts, Battle Art/Dramaless stacks and launcher-ready ZIP validation.

## Compatibility

- Gen1Recomp `>=0.1.69 <2.0.0`.
- Native 2D flight requires no voxel provider.
- Optional voxel providers: Battle Art Voxel Fork `>=1.7.6 <2.0.0` or Dramaless Shape `>=1.6.4 <2.0.0`.
- Use either Wilds of Kanto or PokéPC Followers as the normal follower/sprite setup; they are not intended to be required together.
- Generation II mounts appear only when those species exist in the loaded game data.
- Wild Skies `>=1.4.1 <2.0.0` remains optional and recommended for visible airborne encounters.

## Known limitations

- With `GROUND FOLLOWERS` enabled, the Pokémon currently used as the Ground Ride mount may still appear in the follower trail. The option is OFF by default and this does not affect normal mounted gameplay.
- With Wilds of Kanto, Suicune can briefly show the ordinary Surf mount during the post-battle return before the amphibious Ground Ride presentation is restored.
- The optional Stadium renderer remains experimental and is not part of the validated 0.1.6 feature highlights.

The attached ZIP is launcher-ready: `manifest.json` and `main.lua` are directly at the archive root, and the packaged runtime is rebuilt and compiled with LuaJIT before publication.
