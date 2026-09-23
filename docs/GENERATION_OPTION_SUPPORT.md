# Ride option support, development tree

This inventory describes implementation, not completed gameplay verification.
Native Gen3 has isolated runtime contract tests. Real gameplay, visual,
save/reload and two-player acceptance runs remain pending. Gen1 and Gen2 keep
the shared schema and runtime.

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
| `flying_music` | User catalog/optional packs | Same catalog/pack keys; restores native map music |
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

Online owns transport. Ride exports appearance and pose without changing
remote parties or local settings. GB poses carry visibility and bounded scale;
returned definitions have `dramaticSkyRideNetworkScale`, respected by flat and
voxel paths. Gen3 virtual ids encode species, trainer gender, visibility and
size quantized to 0.05, and accept old ids. Receiver preferences do not rewrite
remote appearance.

## Checks before gameplay testing

- `luajit tests/gen3_options_unit.lua`: isolated progression, movement,
  altitude, appearance, settings-page, battle and safe-save contracts.
- `luajit tests/gen3_skies_unit.lua`: optional-provider absence, altitude,
  shared pending claims, scoped flockmates and failed-start restoration.
- LuaJIT bytecode compilation of native modules and assembled GB source.

Deterministic stubs do not verify GPU output, physical controllers, imported
songs, real connection maps or multiplayer packets. Those remain acceptance
work after implementation.
