# Dramatic Sky Ride 0.4.0-test.2

Development test build for engine 0.3.1. Gameplay testing is pending.

- Native Gen3 consumes the shared ride settings: speed/boost/gallop, stamina,
  altitude and camera control, move/badge/story/discovery gates, remounting,
  Surf art, rider visibility, per-species sizes, hints, feedback and music.
- HGSS mount art works independently. Expanded composite canvases retain large
  mounts, and virtual graphics IDs carry remote size and rider visibility.
- Gen2 grid and continuous flight share active story-event gates; Johto towns
  and routes participate in discovery rules.
- Optional native Wild Skies interception uses its public altitude/claim API.
  Shared encounters wait for the owner grant; optional Doubles consumes a scoped
  flockmate source. Each mod remains independently usable.

Validation: 38 isolated native Ride/settings/network contracts, 14 optional
Skies contracts, and LuaJIT compilation. No user profile or save was changed.
Native Stadium model rendering is still unavailable. Real controller, map
connection, music, capture/interception, visual and multiplayer acceptance
checks remain pending; see docs/GENERATION_OPTION_SUPPORT.md.
