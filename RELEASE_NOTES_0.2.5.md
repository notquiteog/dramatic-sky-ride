## Dramatic Sky Ride 0.2.5

This small follow-up release fixes the Generation II Visible Surf-to-Flight
transition.

### Fixed

- Taking off directly from a visible water mount no longer crops Gold's native
  Surf sprite as the rider and displays it on the back of the Flight mount.
- The Gold player bridge now refreshes its native rider source immediately
  when Surf returns to the normal player state.

### Testing helpers

- A temporary scientist in New Bark Town gives Ho-Oh, Suicune, Raikou and
  Gyarados for rapid Generation II mount testing.
- Set `SETTINGS VIEW = ADVANCED` and `BADGE CHECKS = OFF` to test without badge
  progression requirements.

Generation II mount rendering is validated in native 2D. Voxel and Stadium 2
presentation remains dependent on compatible companion mods becoming
available.

The attached ZIP is launcher-ready and is reconstructed and compiled with
LuaJIT after packaging before publication.
