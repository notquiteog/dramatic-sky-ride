## Dramatic Sky Ride 0.2.6

This follow-up release stabilizes Generation II mount restoration after
battles in Pokemon Gold.

### Fixed

- Flight, Ground Ride and Visible Surf mounts now return only after the game
  has completely left the battle and returned to free roam.
- Visible Surf remembers the exact selected Pokemon across battle cleanup,
  including Gyarados.
- Amphibious Suicune returns correctly on water after battle.
- Gold's generic Surf sprite is no longer cropped and displayed on top of a
  restored Gyarados, Suicune or other custom water mount.
- `REMOUNT AFTER BATTLE` now consistently controls all three mount types.
- A loss, fainted mount, removed mount or otherwise ineligible mount safely
  prevents automatic remounting.

### Generation II testing

- The temporary scientist in New Bark Town still gives Ho-Oh, Suicune,
  Raikou and Gyarados for rapid mount testing.
- Set `SETTINGS VIEW = ADVANCED` and `BADGE CHECKS = OFF` to test without badge
  progression requirements.
- Generation II mount rendering remains validated in native 2D. Voxel and
  Stadium 2 presentation still depends on compatible companion providers.

The attached ZIP is launcher-ready and is reconstructed and compiled with
LuaJIT after packaging before publication.
