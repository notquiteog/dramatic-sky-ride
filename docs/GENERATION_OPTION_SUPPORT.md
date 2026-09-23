# Ride option support, development tree

This inventory distinguishes implementation from completed verification.
Native Gen3 has isolated runtime contracts and the bounded published-archive
checks listed below. Full visual, save/reload, controller and map coverage
remain incomplete. Gen1 and Gen2 keep the shared schema and runtime.

| Setting | Gen1 / Gen2 | Native FireRed / LeafGreen |
| --- | --- | --- |
| `show_rider` | Shared rider rendering | Composite omits trainer; choice travels in virtual graphics id |
| `flight_speed`, `ground_speed` | Shared percentages | Multiply retained `gen3_ride_speed` baseline |
| `flight_boost` | Shared smooth boost | B ramps speed while moving |
| `ground_gallop`, `ground_hud`, `ground_dust` | Shared stamina/gallop/particles | Stamina, ramped speed, gauge, native and optional voxel particles |
| `manual_altitude`, `vertical_speed`, `altitude_display` | Shared altitude/HUD | Page Up/Down or triggers; 20–96 px bounds; rate and HUD controls |
| `camera_follow`, `camera_altitude` | Optional voxel camera | Optional `gen3Camera` yaw/pitch; 2D centers airborne rider |
| `mount_shortcut` | H/X flight, G/J/Y ground | H/X flight, G/Y ground; remembers usable mount |
| `flight_feedback`, `mount_cries` | Shared sound/rumble | Native cries, flight sound and controller vibration |
| `require_fly_move`, `badge_checks` | Generation-specific requirements | Native FRLG move/badge requirements, independently switchable |
| `story_safe` | Quest collisions; Gen2 grid/continuous paths share gate | Native object collision during flight |
| `story_gates` | Gen1 data gates; Gen2 scene coordinate gates | Active coordinate events and native connection barriers |
| `discovery_gates` | Kanto/Johto destinations use visitation ledger | Canonical FR outdoor connections require prior grounded visitation |
| `reverse_ledge_jumps` | Shared mounted ledges | Native low ledges only; landing collision retained |
| `remount_after_battle` | Shared restore | Suspend in battle; resume only with healthy same mount on same map |
| `visible_surf_mounts` | Shared Surf | Native Surf adopts eligible party mount; off restores native art |
| `mount_menu`, `mount_hints` | Shared menu/hints | START entry and first-use reminders |
| `show_followers_while_mounted` | Ground only; default off | `shouldShowFollowers()` policy for optional providers |
| `pokedex_mount_sizes`, `mount_size_*` | Shared scales | Native height plus override; canvas expands to avoid clipping |
| `flying_music` | User catalog and public merged Surf/Bike records; Crystal playback/restoration verified | Local user catalog works; **external registry tracks unavailable on official 0.3.1**, which gates off Gen3 `content.music` |
| `air_encounters` | Optional Wild Skies | Public Wild Skies physical interception/claim API plus `allowAirEncounters()` policy; requires airborne provider |
| `settings_view`, `size_overrides` | Shared presentation | Native page filters/refreshes in place; retains hidden values |
| `flight_mount_renderer` | Optional imported Stadium | **Unavailable:** native Gen3 Stadium model/rig renderer unported |
| `landing_marker`, `dynamic_shadow` | Already retired | Remain retired; no duplicate ground entities |

Legacy Gen3 `gen3_rides`, `gen3_ride_speed`, and `gen3_flight_height` remain.
Shared keys retain Gen1 defaults, including Advanced view and followers off.
Embedded HGSS sheets work independently; installed sprite providers supply
their selected style.

Ride has no required companion dependencies. Voxel cameras, followers, airborne
encounters, external music and online transport remain optional. Integration
policies do not claim that an absent provider supplies a feature.

Music uses the active file-backed `content.music` Surf/Bike definitions, with
Gen2 song-name aliases. It does not inspect private pack directories or offer
every hidden track in simultaneously installed packs. Old `frlg_*`, `hgss_*`
and `lgpe_*` selections require choosing a public registered track again;
Ride does not silently map them to a different provider. Custom local catalog
keys and the default `none` are unchanged. An absent public music provider
adds no installed-track choices. Official engine 0.3.1 rejects Gen3 music
registrations, so its native shared registry consumer cannot receive provider
tracks. This was reproduced with a disposable generated-tone provider. The
native local catalog is independent of that registry and remains supported.
No additional native music-provider API is included in this release.

Online owns transport. Ride exports appearance and pose without changing
remote parties or local settings. GB poses carry visibility and bounded scale;
returned definitions have `dramaticSkyRideNetworkScale`, respected by flat and
voxel paths. Gen3 virtual ids encode species, trainer gender, visibility and
size quantized to 0.05, and accept old ids. Receiver preferences do not rewrite
remote appearance.

## Verification and remaining coverage

- `luajit tests/gen3_options_unit.lua`: isolated progression, movement,
  altitude, appearance, settings-page, battle and safe-save contracts.
- `luajit tests/gen3_skies_unit.lua`: optional-provider absence, altitude,
  shared pending claims, scoped flockmates, failed-start restoration and the
  engine's exact event-prefix rule.
- `luajit tests/flying_music_unit.lua`: public registry discovery, aliases,
  intro/loop playback, pause/quit restoration and invalid-asset handling.
- LuaJIT bytecode compilation of native modules and assembled GB source.

Published 0.4.0-test.2 passed two-endpoint FireRed mount/flight/landing and
disconnect-cleanup checks on engine 0.3.1. Its shared aerial battle failure
was traced to an event-prefix exception after battle entry; test.3 corrects
that exception. Published test.3 passed these additional engine 0.3.1 checks:

- Crystal public generated-tone Surf choice, intro/loop playback and map-music
  restoration after landing.
- LeafGreen two-endpoint mount, flight-height, landing and disconnect cleanup
  with all six published mods enabled.
- FireRed shared aerial claim entry, battle completion, host consumption and
  persistent room with Wild Skies 1.13.0-test.2.

The FireRed public-music fixture confirmed the engine registry limitation;
that test is not a native external-music playback pass. Physical controllers,
commercial/imported music packs, real connection maps and native Stadium
rendering remain outside the completed checks.
