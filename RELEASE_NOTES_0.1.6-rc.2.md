# Dramatic Sky Ride 0.1.6-rc.2

Development candidate for the next compatibility preview. This version is **not published automatically** from the development branch.

## Native 2D flight

- Flight no longer requires an active voxel pipeline.
- Flat 2D uses the same flight state, altitude, collision and progression logic as voxel flight.
- The trainer is drawn first and the mount second, producing a readable seated pose without a second y-sorted rider entity.
- Existing Pokédex-proportional mount sizing and per-species size controls apply to the 2D mount automatically.

## Renderer priority

- Added `FLIGHT RENDERER`.
- `2D SPRITES` is the default and preferred mode.
- `STADIUM 3D` is an explicit opt-in only.
- Stadium becomes effective only when Pokémon Stadium Overworld Models is installed, a voxel pipeline is active, and the current species is supported; otherwise DSR falls back to 2D without refusing takeoff.
- Generation II mounts therefore remain visible as 2D billboards with the current Stadium 1 provider, while future 3D providers can advertise explicit per-species support.
- Canonical inter-mod flight state remains renderer-independent through `isFlying()`, `altitude()` and `mount()`.

## PokéPC provider target

- The officially tested PokéPC implementation is now the maintained `mfrtechconsult/PokePCFollowers` compatibility fork.
- The fork retains the shared `PokePCFollowers_VoxelMerge` mod id for compatibility and exposes explicit provider repository/API metadata.
- DSR detects that metadata for diagnostics while older PokéPC builds sharing the id remain best-effort legacy fallbacks.
- The maintained fork exposes Generation I + II sprite-provider coverage.

## Generation II mounts

Generation II activation is based on National Pokédex data rather than a hard Crystal 251 dependency. A compatible content mod supplies Pokémon 152–251 and Wilds of Kanto or `mfrtechconsult/PokePCFollowers` supplies the overworld art.

- **Flight:** Noctowl, Crobat, Xatu, Skarmory, Lugia, Ho-Oh.
- **Ground Ride:** Meganium, Girafarig, Ursaring, Donphan, Stantler, Raikou, Entei, Suicune, Tyranitar.
- **Visible Surf:** Feraligatr, Mantine, Kingdra, Lugia.
- Added Pokédex-derived size controls and Gen2 Ground Ride speed profiles.
- Provider resolution retries by National Dex when a provider uses different species-name punctuation/normalization.

## Suicune seamless water running

- Suicune is the **only amphibious Ground Ride mount**.
- Once normal Surf progression is unlocked, Suicune can run land → water → land without dismounting or changing into the Visible Surf mount system.
- The terrestrial running sprite and Ground Ride lifecycle remain continuous on water.
- Native Surf collision is armed before the water step instead of overriding a rejected collision afterwards, preserving water tile pairs, map connections and third-party collision hooks.
- Cycling Road and Seafoam Surf restrictions remain respected.
- Water-to-water map connections are supported.
- Battle recovery can remount Suicune directly on water when it remains usable.
- Ground dust is suppressed while Suicune is running on water.

## Existing compatibility work retained

- Wilds of Kanto follower/sprite integration and cooperative update-hook recovery.
- The Gen2/Suicune update wrapper is included inside the protected DSR chain.
- Wild Skies airborne encounter integration.
- Optional Flying Music from installed FRLG/HGSS/LGPE music packs without redistributing third-party audio.
- Dramaless and Battle Art compatibility coverage with Dramatic Deep Dive / Kanto Dive.

## Testing focus

Please test these paths independently:

1. Wilds of Kanto + DSR, with a Gen2 content provider, testing a flight mount, Ground Ride mount and Visible Surf mount.
2. `mfrtechconsult/PokePCFollowers` + DSR, without Wilds, repeating the same Gen2 tests.
3. Suicune: repeated land → water → land transitions, shoreline turns, map seams, battle-on-water → remount, and Surf progression blocked/unblocked cases.
4. Battle Art and Dramaless with both 2D sprites and Stadium selected, confirming unsupported Gen2 species safely stay 2D.
