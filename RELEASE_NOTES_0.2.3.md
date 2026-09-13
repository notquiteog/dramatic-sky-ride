# Dramatic Sky Ride 0.2.3

## Gen 1 stability fix

This release fixes a cooperative update-hook regression found while preparing the Generation II compatibility path.

- Flight now completes takeoff and moves normally when Wild Skies and Wilds of Kanto are active.
- Visible Surf now initializes its mount and preserves normal Surf movement.
- DSR keeps its complete Flight, Ground Ride and Surf update chain when another compatible mod wraps the overworld update handler.
- False watchdog recovery no longer rewires a healthy composed wrapper chain.
- The new regression coverage includes the Gen 1 Surf and Gold Suicune wrapper layers.

The fix was exercised in Gen1Recomp 0.1.77 with Blastoise Visible Surf, Ho-Oh Flight, Wilds of Kanto, Wild Skies, Dramaless Shape and a generated Crystal 251 Stadium 2 cache. Native Stadium 2 Ho-Oh rendering was also verified with the voxel pipeline enabled.

## Generation II status

Generation-aware runtime, progression and Gold Suicune support are included for continued beta testing. Generation II is **not yet declared in the standard release manifest** while real Gold testing continues. The dedicated Gen2 beta artifact remains the opt-in test package.

## Dependencies

DSR still has no mandatory companion-mod dependency. Native 2D Flight, Ground Ride and Visible Surf remain the fallback. Wilds of Kanto, Wild Skies, voxel renderers, Crystal 251, Stadium providers, follower providers and music packs remain optional integrations.

## Installation

The attached ZIP is launcher-ready with `manifest.json` at its root. Stadium 2 models are not bundled; Crystal 251 generates them locally from the player's own compatible ROM.
