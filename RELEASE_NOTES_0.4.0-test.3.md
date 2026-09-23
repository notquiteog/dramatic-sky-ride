# Dramatic Sky Ride 0.4.0-test.3

Test patch for engine 0.3.1.

- Fix the exact manifest-owned event prefix after aerial battle entry. The
  previous lowercase prefix threw after starting battle, causing Online to
  release a shared flyer claim before Wild Skies could record ownership.
- Replace removed mod-directory scans with public merged Surf/Bike music
  records. Gen1/2 and native Gen3 share `installed_surf` / `installed_bike`
  keys; native playback retains intros, loops and map-music restoration.
- Preserve custom local catalog keys and default `none`. Private tracks from
  every installed pack are not enumerated; old pack-specific selections must
  be reselected from the active public tracks.

Validation: 38 native Ride contracts, 15 optional Skies contracts, 19 public
music/playback contracts, native LuaJIT compilation and assembled GB source.
Published test.2 passed two-endpoint FireRed Ride synchronization, while the
shared aerial failure above was reproduced on its published archive. These
source fixes still need acceptance on the newly packaged test.3 archive.
Physical controller, imported music and map-connection coverage is incomplete.
Native Stadium rendering remains unavailable. No live game profile was changed.
