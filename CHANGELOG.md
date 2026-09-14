## 0.2.20 — Native Crystal camera input

When Battle Art advertises native Gen 2 world support, its camera input
predicate remains authoritative. The older Sky Ride bridge used the mounting
predicate, which refuses in-progress steps, interrupting ordinary 1ST/3RD
walking. Older providers retain the existing bridge; flight handling is unchanged.
Verified with Battle Art's Crystal camera driver: both rungs walk east through
native completed grid steps while forward is held at an east-facing camera yaw.
The bridge regression test covers modern/legacy providers on both generations.

## [0.2.19] - 2026-09-13 - JohtoDioramaCart fork: the Crystal rider crash

Forked from burgerslayer7/dramatic-sky-ride v0.2.18. One fix, Generation
1 untouched:

- The rider crop is verified through the engine's own asset reader before
  the battle renderer ever sees it.  On hosts that reroute mod filesystem
  writes to the mod's private storage, the crop file lands where the
  renderer cannot open it and Crystal's SPRITE_CHRIS rider crashed the
  draw ("Could not open file .../rider_SPRITE_CHRIS_c13_y1.png").  When
  the crop is unreadable the rider now falls back to the live player
  renderer -- the same palette-correct fallback the mod already uses when
  ImageData encoding is unavailable -- instead of crashing.  Where the
  engine can read the crop, the cropped sheets work exactly as before.

# Changelog

## 0.2.18

- Restored the complete pre-sandbox 0.2.11 runtime and mount system.
- Restored the legacy filesystem-backed provider and Stadium 2 animation paths.
- Removed every sandbox-era runtime, Open Sky and bundled fallback change introduced from 0.2.12 onward.
- Preserved the historical 0.2.11 Flight, Ground Ride, Visible Surf and continuous Gen 2 movement behavior without modification.

## 0.2.8

- Aligned Generation II Ground Ride map restrictions with Gold's native Bicycle environments.
- Automatically dismounted terrestrial mounts after entering indoor buildings or dungeons through native Gold warps.
- Preserved Ground Ride through towns, routes, caves, gatehouses and seamless inter-map passages.
- Kept amphibious Suicune mounted on water while applying the new building guard.
- Added regression coverage for the Generation II Ground Ride environment policy.

## 0.2.7

- Suppressed Gold's ground-level grass rustle animation while Flight is active.
- Kept native grass state, encounters, collisions and all non-Flight movement behavior unchanged.
- Added regression coverage for the Generation II Flight terrain-effect guard.

## 0.2.6

- Restored Flight, Ground Ride and Visible Surf mounts only after Gold has fully returned to free roam following a battle.
- Preserved the exact selected Visible Surf mount across battle cleanup, including Gyarados and amphibious Suicune.
- Prevented Gold's generic native Surf sheet from being cropped and displayed on top of a restored custom water mount.
- Applied `REMOUNT AFTER BATTLE` consistently to Flight, Ground Ride and Visible Surf.
- Kept loss, fainted-mount and unavailable-mount outcomes safe by declining an invalid automatic remount.
- Added Generation II post-battle remount regression coverage and a complete Lua 5.1 runtime compilation check.

## 0.2.5

- Fixed the Gold Visible Surf mount appearing on the back of the Flight mount when taking off directly from water.
- Refreshed the native Gold rider source synchronously during the Surf-to-Flight state change.
- Added regression coverage for Gyarados-to-Ho-Oh switching.
- Documented the temporary New Bark Town test giver and the optional badge-check bypass.

## 0.2.4

- Declared Generation II support in the standard release manifest.
- Added Gold-native live-player rendering for Flight, Ground Ride and Visible Surf mounts.
- Added Generation II Flight, Ground and Surf mount rosters with native 2D fallback art.
- Fixed Gold movement, landing and shortcut activation paths that bypass Gen 1 compatibility methods.
- Added airborne route/city connection traversal while preserving authored topology and progression gates.
- Added Gold reverse-ledge Ground Ride jumps while keeping ordinary walls, warps, water and occupied cells blocked.
- Added native Gold Surf-state activation for Flight water landings, ordinary Surf, water movement and shoreline exits.
- Added Generation II Pokedex height fallbacks and corrected live 2D mount scaling.
- Added a temporary New Bark Town test NPC that supplies Ho-Oh, Suicune, Raikou and Gyarados with the required field moves.
- Kept Generation II voxel/Stadium presentation provider-dependent; the validated Gen2 path for this release is 2D.

## 0.2.3

- Fixed Flight and Visible Surf being bypassed when Wild Skies re-armed its overworld update watchdog around DSR.
- Preserved the complete update chain across the Gen 1 Surf and Gold Suicune compatibility wrappers.
- Prevented false recovery when a cooperative outer watchdog still owns the DSR root.
- Added native Surf-state recovery so Visible Surf can initialize after a displaced update hook.
- Added regression coverage for cooperative Wilds/Wild Skies update composition.
- Included the generation-aware Gen 2 compatibility path for continued beta testing without declaring Gen 2 in the standard release manifest.
- Kept Wilds, voxel renderers, Crystal 251 and every other companion integration optional; native 2D remains the dependency-free fallback.

## 0.1.7

- Added fully optional OTF Player Switcher compatibility so mounted rider art follows the selected player character during Flight, Ground Ride and Visible Surf.
- Reserved Page Up/Page Down for DSR altitude control while Flight is active, while OTF retains its shortcuts outside Flight.
- Added a native high-detail PokeMMO mount path for Wilds of Kanto that reads the original 32/64 px atlas only when Wilds is explicitly using its PokeMMO sprite style.
- Corrected PokeMMO apparent mount sizing by trimming stable shared transparent padding before applying DSR's Pokédex/user scale.
- Added canonical Generation II height fallbacks for coherent Johto mount sizing when the active Gen2 content provider does not publish dex height fields.
- Stabilized flat 2D Flight over tall buildings: automatic safety altitude remains active for gameplay/collision but no longer causes a visible mount/rider jump in the top-down renderer.
- Added defensive chunk-boundary normalization to the runtime loader and aligned release validation with the exact loader behavior.
- Kept OTF, Wilds, PokéPC, Battle Art, Dramaless, Wild Skies, music packs and Gen2 content providers optional according to their existing roles.
- Known limitation: with `GROUND FOLLOWERS` enabled, the active Ground Ride mount may still appear in the follower trail.
- Known limitation: with Wilds of Kanto, Suicune may briefly show the ordinary Surf mount during post-battle return.
- The optional Stadium renderer remains experimental and is not part of the validated 0.1.7 highlights.

## 0.1.6

- Added native flat-2D flight; a voxel provider is no longer required to take off.
- Added Wilds of Kanto as a supported sprite/follower runtime and removed the hard PokéPC dependency.
- Made `mfrtechconsult/PokePCFollowers` the preferred PokéPC compatibility fork while retaining legacy fallback compatibility.
- Added Generation II flight, Ground Ride and Visible Surf mounts through National Pokédex data without hard-depending on Crystal 251.
- Added Suicune-exclusive seamless land/water Ground Ride while preserving normal Surf progression and restrictions.
- Added Generation II speed/gallop profiles, rider offsets and Pokédex-proportional size controls.
- Added a public airborne 2D sprite-source registration API.
- Added optional Flying Music using installed FRLG/HGSS/LGPE packs without redistributing their audio.
- Added cooperative/self-healing overworld update protection for Wilds and companion-mod stacks.
- Improved Gen II mount facing in supported 1ST/3RD camera modes and Suicune continuity across map seams and water battles.
- Followers are hidden by default while mounted; `GROUND FOLLOWERS` is a land Ground Ride-only opt-in and followers remain hidden during Flight and Surf.
- Added expanded CI for native 2D loading, Wilds, Gen II contracts, Battle Art/Dramaless stacks and launcher-ready release ZIP validation.
- Known limitation: with `GROUND FOLLOWERS` enabled, the active Ground Ride mount may still appear in the follower trail.
- Known limitation: with Wilds of Kanto, Suicune may briefly show the ordinary Surf mount during post-battle return.
- The optional Stadium renderer remains experimental and is not part of the validated 0.1.6 highlights.

## 0.1.6-rc.2 — development

- Added native flat-2D flight. An active voxel pipeline is no longer required to take off.
- Reused the existing renderer-independent flight state, collision, altitude, progression, encounter and battle logic rather than creating a second 2D flight engine.
- Added deterministic flat composition: the trainer is drawn first and the mount second so the Pokémon body hides the rider crop line and reads as a seated ride.
- Removed the separate rider entity from flat 2D while retaining it for voxel rendering, preventing duplicate Red sprites and y-sort-dependent seating.
- Reused existing Pokédex-proportional mount sizing and per-species size controls in flat 2D.
- Added `FLIGHT RENDERER` with **2D SPRITES** as the default/preferred choice and **STADIUM 3D** as an explicit opt-in.
- Stadium 3D becomes effective only when Pokémon Stadium Overworld Models is installed and a voxel pipeline is active; otherwise DSR falls back to 2D without refusing takeoff.
- Kept the canonical renderer-independent compatibility surface aligned with the Free Fly/Wild Skies ecosystem: `isFlying()`, `altitude()` and `mount()`.
- Added `flightRendering` inspection and upgraded `stadiumCompatibility` to API 2 with requested/effective renderer state.
- Kept the existing `currentAltitude()` Stadium alias, but `mountSpecies()` is now gated by effective Stadium 3D opt-in so installing Stadium alone does not select a 3D DSR mount.
- `currentLift()` remains intentionally unimplemented rather than publishing an approximate value with incompatible semantics.
- Added a ROM-free no-voxel regression that loads DSR with Wilds/PokéPC and asserts 2D is the default/effective renderer.
- Compatibility prerelease publication is now manual; normal development pushes continue to run CI without mutating an already published RC/tag.

## 0.1.6-rc.1 — compatibility preview

- Added Wilds of Kanto (`overworld_wild_spawns`) as a compatible authoritative follower/sprite runtime.
- Removed the hard manifest dependency on PokéPC Followers for this compatibility branch; Wilds of Kanto or PokéPC Followers can provide compatible Pokémon overworld sprites.
- Added cooperative overworld update-hook protection so DSR, Wilds and compatible companion mods can coexist without silently replacing each other's wrapper chains.
- Added compatibility regression coverage for Wilds + DSR + Dramatic Deep Dive / Kanto Dive with both Dramaless Shape and Battle Art Voxel Fork.
- Added a read-only Pokémon Stadium Overworld Models compatibility API: `isFlying()`, `currentAltitude()`, `mountSpecies()` and `stadiumCompatibility`.
- Added optional `FLYING MUSIC` support with `None` as the default.
- Added automatic reuse of installed DarioMelo `Music_FRLG`, `Music_HGSS` and `Music_LGPE` Surf/Bike OGG assets without copying or redistributing third-party music.
- Added an extensible `audio/flying/tracks.lua` catalog for future redistributable or user-supplied flight tracks.
- Preserved battle, victory, jingle and direct music priority; landing restores normal map/Surf music.
- Kept the Flying Music manifest scan independent of network-gated `src.link.Json` by reusing DSR's lightweight manifest-id parser.
- Retained the 0.1.5 canonical Dramaless `voxel` pipeline fix and legacy `st_voxel` fallback.
- Added a dedicated compatibility prerelease workflow that rebuilds and LuaJIT-validates the exact launcher-ready ZIP before publishing it as a GitHub prerelease.

## 0.1.5

- Fixed Dramaless Shape voxel detection: current Dramaless releases register the canonical `voxel` pipeline, not `st_voxel`.
- A stale or incorrect provider pipeline hint no longer makes DSR report `Turn VOXEL on before taking off.` while a supported voxel pipeline is visibly active.
- Added a compatibility fallback that checks `voxel` first and retains `st_voxel` only for older forks.
- Added a one-time provider/pipeline/level diagnostic log to simplify future compatibility reports.
- Battle Art Voxel Fork remains preferred when both providers are installed and continues to use its existing `voxel` pipeline unchanged.
- No Flight, Ground Ride, visible Surf, Wild Skies or music functionality was added or changed in this bugfix release.

## 0.1.4

- Raised the supported Dramaless Shape baseline to `DRAMALESS_SHAPE >=1.6.4 <2.0.0`.
- Dramaless Shape 1.6.4 keeps the public `exports.lib` API and `st_voxel` pipeline used by DSR while fixing the 1ST/3RD menu softlock and camera-control issues present in 1.6.3.
- Battle Art Voxel Fork remains supported at `BATTLE_ART_VOXEL_FORK >=1.7.6 <2.0.0`; its latest release and `feature/battle-art` branch are still identical at 1.7.6.
- No flight, Ground Ride, visible Surf or Wild Skies gameplay behavior changed in this compatibility release.

## 0.1.3

- Added Dramaless Shape (`DRAMALESS_SHAPE`) as a supported alternative voxel provider alongside Battle Art Voxel Fork.
- Provider integration now uses the selected provider's public `exports.lib` API and exported voxel pipeline id (`voxel` or `st_voxel`).
- Battle Art Voxel Fork remains preferred when both supported providers are installed.
- Added global `FLIGHT SPEED` and `GROUND SPEED` options from 50% to 200%, while preserving species-specific profiles, Flight boost and Ground gallop behavior.
- Applied the global speed multipliers to standard movement, voxel 1ST/3RD FreeMove and seamless connected-map movement paths.
- When Dramaless is selected, Ground Ride automatically uses `J` because Dramaless reserves `G` for V-GRID; controller `X`/`Y` controls remain unchanged.
- Removed the temporary Ground Ride `JUMP` notice while keeping jump animation, audio, rumble and landing feedback.
- Removed the `Visible Surf mount active.` activation dialog without changing visible Surf behavior.
- Retained the 0.1.2 Surf 3RD camera correction and Wild Skies 1.4.1+ two-cell interception envelope.

## 0.1.2

- Fixed visible Surf in Battle Art Voxel Fork `3RD`: water cells no longer collapse the third-person camera boom as if they were pedestrian obstacles, so the trainer and Surf mount remain visible at normal camera angles.
- Kept `1ST` as a true first-person view; DSR does not force the trainer or mount into the first-person camera.
- Updated the recommended Wild Skies baseline to `1.4.1+`.
- Increased DSR's Wild Skies interception envelope from one cell to two cells, making mid-air encounters substantially easier with Wild Skies' newer three-dimensional roaming flocks.
- Wild Skies remains optional and independent; DSR continues to use only its public `registerSpriteSource` / `takeFlyer` integration surface.

## 0.1.1

- Promoted the validated Battle Art compatibility work to stable.
- `BATTLE_ART_VOXEL_FORK >=1.7.6 <2.0.0` is now the primary required voxel provider.
- `PokePCFollowers_VoxelMerge` is now required as the overworld Pokémon/NPC sprite provider used by mount rendering.
- The retired `DRAMATIC_SHAPE` provider is no longer a supported manifest dependency; a best-effort runtime fallback remains for old manual installs.
- DSR now selects Battle Art Voxel Fork first through its public `exports.lib` API and does not patch Battle Art sprite/battle internals.
- Added Battle Art staged-battle lifecycle protection so Ground Ride entities are removed before the battle-world snapshot and restored cleanly afterward.
- Moved the keyboard Flight shortcut from `F` to `H` because Gen1PC Overworld Encounters reserves `F`/`V` for follower attacks.
- Ground Ride remains `G`; controller shortcuts are `X` for Flight and `Y` for Ground Ride.
- Wild Skies remains optional but is strongly recommended; DSR uses its public API for visible airborne Pokémon and exact species/level aerial encounters.
- Release packaging is validated by reconstructing the exact packaged `sky_ride.lua` and compiling it with LuaJIT before publication.

## 0.1.0

- Promoted the validated alpha.16 feature set to the first stable Dramatic Sky Ride release.
- Removed the experimental manifest flag and restored GitHub/Mod Index update metadata for stable SemVer releases.
- Added story-aware FLY progression: optional FLY requirement, THUNDERBADGE takeoff gate, SOULBADGE water-landing gate and data-driven story gates.
- Added `DISCOVERY GATES`: first-time airborne entry into canonical vanilla Kanto routes/cities is blocked until the map has been reached through normal gameplay.
- Unknown/custom map ids remain allowed by default for map-pack and total-conversion compatibility.
- Added camera-directed altitude in Dramatic Shape 1ST/3RD modes.
- Added optional Wild Skies integration through its public API, including real per-species follower/overworld sprites when available and exact visible flyer species/level battles.
- Kept Wild Skies separate and optional; Free Fly remains a conflicting alternative flight engine.
- Includes the alpha.16 startup/scope fixes and the Ground Ride sizing crash fix validated during testing.
