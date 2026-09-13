# Dramatic Sky Ride 0.1.6-rc.4 — development test build

This is a launcher-ready development build for in-game compatibility testing. It is not a stable release.

## Fixed from rc.3 testing

- Suicune can enter water from land while 1ST/3RD FreeMove owns locomotion; normal Surf progression restrictions remain enforced.
- Mounted followers enabled by `MOUNT FOLLOWERS` keep the authoritative Wilds trailer runtime instead of being removed/reseeded at the player.
- The active mount follower is hidden non-destructively while other followers keep their normal trail/follow behaviour.
- Suicune remains the visible player mount throughout a water battle transition; the stock Pokémon Red Surf sprite is no longer allowed to own the handoff pose.
- Generic visible-Surf rendering stays suppressed until Suicune has successfully remounted after battle, preventing the brief alternate Surf-mount flash.

## Still deferred

- Stadium 3D mount activation is not part of this pass.
