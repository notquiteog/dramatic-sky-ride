# Dramatic Sky Ride 0.4.0-test.3

Test patch for engine 0.3.1.

- Fix the exact manifest-owned event prefix after aerial battle entry. The
  previous lowercase prefix threw after starting battle, causing Online to
  release a shared flyer claim before Wild Skies could record ownership.
- Replace removed mod-directory scans with public merged Surf/Bike music
  records. Gen1/2 use `installed_surf` / `installed_bike` keys. Official
  engine 0.3.1 gates off `content.music` for Gen3, so native external registry
  tracks are unavailable even though Ride has the shared consumer. Native
  user-supplied local catalogs retain intro/loop playback and map restoration.
- Preserve custom local catalog keys and default `none`. Private tracks from
  every installed pack are not enumerated; old pack-specific selections must
  be reselected from the active public tracks.

Validation: 38 native Ride contracts, 15 optional Skies contracts, 19 public
music/playback contracts, native LuaJIT compilation and assembled GB source.
Published test.2 passed two-endpoint FireRed Ride synchronization, while the
shared aerial failure above was reproduced on its published archive.

Published test.3 archive checks on official engine 0.3.1:

- Crystal: a disposable provider registered a generated Surf track through
  `content.music`; selecting it played its intro and loop, and landing
  restored New Bark Town music.
- FireRed: the same provider confirmed that the engine rejects Gen3 music
  registrations. No installed-track choice was exposed and Ride made no
  private filesystem scan. This is a measured limitation, not a playback pass.
- LeafGreen: all six published mods passed two-endpoint mount, flight-height,
  landing and disconnect-cleanup checks.
- FireRed shared aerial encounter: both endpoints passed native claim entry,
  battle completion, host consumption and persistent-room checks with
  Wild Skies 1.13.0-test.2.

Physical controllers, commercial/imported music packs and map connections
have incomplete gameplay coverage. Native Stadium rendering remains
unavailable. No live game profile was changed.

Follow-up test release. Native gameplay checks follow publication; original archives passed shared ground-sky encounters, riding synchronization, native doubles and trading on 0.3.1.
