# Dramatic Sky Ride alpha.16 experimental validation checklist

Alpha.16 is developed only on `feature/wild-skies-integration`. It adds story-aware FLY progression, legitimate-discovery safeguards, camera-driven altitude in `1ST`/`3RD`, and optional integration with ShaneHudson's separate Wild Skies mod.

## Alpha.16 progression rules

- Confirm that the mod options screen exposes the existing options plus `REQUIRE FLY`, `BADGE CHECKS`, `STORY GATES`, `DISCOVERY GATES`, `CAMERA ALTITUDE` and `AIR ENCOUNTERS`.
- With `REQUIRE FLY` enabled, try to take off with a supported mount that does not know FLY; confirm `FLY REQUIRED` and no takeoff.
- Teach FLY to the mount but remove/withhold THUNDERBADGE; confirm `THUNDERBADGE REQUIRED`.
- With FLY and THUNDERBADGE, confirm party action, keyboard shortcut and gamepad shortcut all take off normally.
- Disable `REQUIRE FLY` and `BADGE CHECKS` separately and confirm each rule can be relaxed without disabling the other.
- Approach a connected-map route protected by `field.badgeGates` while airborne; confirm the crossing is blocked until the required badge/event has been satisfied.
- With `BADGE CHECKS` enabled, attempt a water landing with a SURF user but without SOULBADGE; confirm the landing is refused.
- Add SOULBADGE and confirm the same landing transitions directly into native Surf.

## Alpha.16.4 discovery safeguards

- Confirm `DISCOVERY GATES` is enabled by default.
- Reach a vanilla route/city normally, then take off and re-enter it from a connected map; confirm airborne re-entry is allowed.
- From a save where a connected vanilla route has never been reached normally, try to cross into it while airborne; confirm `AREA NOT VISITED` and no transition.
- Before legitimate Saffron access, try to enter `SAFFRON_CITY` while airborne; confirm it is blocked. Enter Saffron normally later, then confirm airborne re-entry becomes allowed.
- Confirm entering a vanilla map while DSR flight is active does not mark it as legitimately reached.
- Confirm walking, Ground Ride, native Surf and ordinary/scripted non-flight map entries do mark the destination as legitimately reached.
- Install alpha.16.4 on an existing save and confirm the map currently loaded at startup is seeded as legitimately reached.
- Enter a custom/unknown map id through an airborne connection and confirm it remains accessible by default.
- Disable `DISCOVERY GATES` and confirm only the visited-area rule is relaxed; `STORY GATES`, FLY and badge checks remain independent.
- For an integration using `flightRules.registerDiscoveryGate(mapId, true)`, confirm an opted-in custom map is blocked until `markMapReached(mapId)` is called.

## Alpha.16 camera altitude

- In `1ST`, look upward with the right stick and confirm requested altitude rises smoothly.
- Look downward and confirm requested altitude falls smoothly.
- Repeat with mouse look and touch look where available.
- Repeat the same checks in `3RD`.
- Enter `1ST` or `3RD` while already airborne and confirm the camera's initial pitch reset does not change altitude by itself.
- Hold the right stick against the camera's vertical pitch limit and confirm altitude can continue to change.
- Confirm `R2/L2` and `Page Up/Page Down` still work and take priority when held.
- Change `VERTICAL SPEED` and confirm camera-driven altitude follows the same speed setting.
- Disable `CAMERA ALTITUDE` and confirm looking around no longer changes altitude.

## Alpha.16 Wild Skies integration

- Install `wild_skies` and PokePC follower sprites; keep `free_fly` disabled because DSR and Free Fly are alternative flight engines.
- Confirm Wild Skies still owns spawning, landing, resting, takeoff, night populations and route-seam behaviour.
- Confirm flying species use their real species-specific follower/overworld sprite when `follower_###.png` is available.
- Verify Pidgey/Pidgeotto, Spearow, Zubat/Golbat and at least one sea-route flyer rather than testing only DSR mount species.
- While grounded, confirm Wild Skies low-flyer bump encounters still work normally.
- While DSR is airborne, confirm low flyers do not trigger the grounded bump path.
- Intercept a visible flyer in the same cell/radius and confirm the battle uses that exact species and level.
- Win, run and capture from an intercepted battle; confirm DSR restores mount, altitude, boost and rider state.
- Faint/remove the selected mount during the intercepted battle and confirm DSR performs its existing safe landing.
- Confirm an overworld ground-roamer mod cannot start a ground wild battle while DSR is airborne.
- Disable `AIR ENCOUNTERS`; confirm Wild Skies remains visible/alive but DSR no longer consumes flyers into mid-air battles.
- Uninstall/disable Wild Skies and confirm DSR operates normally with no errors.

Known Wild Skies API limitations for this experiment:

- `takeFlyer()` currently exposes species and level but not flyer altitude/mode, so interception is cell-radius based rather than true 3D distance.
- Wild Skies currently applies its own `dexScale()` after sprite resolution, so real DSR-provided sprites do not yet use DSR's exact mount sizing formula.

## Core regression

- Toggle `SHOW RIDER`, `FLIGHT BOOST`, `GROUND GALLOP` and `VISIBLE SURF MOUNTS`; confirm each feature follows its setting.
- Restart Gen1Recomp and confirm the selected values remain saved.
- Run one takeoff/landing, one Ground Ride gallop and one Surf transition to confirm no behavioural regression.
- Test with the current supported Gen1Recomp and Dramatic Shape 1.7.x releases.
- Install Dramatic Shape through the in-game Mod Manager ZIP flow and confirm flight terrain-height compensation remains active.

## Ground Ride

- Press `G` from a normal outdoor map and confirm Ground Ride starts without a crash before continuing the wider integration checklist.
- Mount and dismount every supported species.
- Compare Tauros and Snorlax movement profiles.
- Hold `B` in 2D, `1ST` and `3RD`; confirm acceleration, stamina, HUD and dust.
- Cross route/town connections at maximum gallop without a speed break.
- Traverse compatible cave floors and map connections.
- Jump official ledges in both directions and reject blocked, water, warp or occupied landings.

## Battles and party changes

- Win, run from and lose a wild battle while Ground Riding.
- Complete a trainer battle while Ground Riding.
- Faint, remove, reorder or evolve the selected Ground Ride Pokemon.
- Trigger a wild battle while airborne and confirm altitude, boost and rider rendering return correctly.
- Faint or remove the selected flying mount during battle and confirm safe landing.
- Confirm that no rider or trainer ghost entity remains after battle.

## Interactions

- Talk to an NPC and read a sign while mounted.
- Use an item pickup, PC, slot machine, Cut, Surf, fishing, Fly, Dig/Teleport and Strength boulder push; confirm safe dismount before the native action.

## Surf and flight

- While airborne, open a Surf-capable Pokemon's party submenu and confirm native `SURF` is not available.
- While airborne, confirm `SURF & RIDE` is not available and `MOUNTS` contains no `SURF` entries.
- Attempt any native Surf activation path while airborne and confirm it is refused with `LAND FIRST`.
- Land on water with the required progression and a Surf-capable party and confirm Surf starts automatically.
- Confirm the visible Surf mount activates after that water landing.
- Take off again from Surf.
- Land on dry ground and confirm normal manual Surf is available again.
- Select each visible Surf mount through `MOUNTS` while not flying.
- Confirm the existing flight camera behaviour in `1ST` and `3RD` remains stable with `CAMERA ALTITUDE` disabled.

## Installation regression

- Validate `manifest.json`.
- Compile `main.lua`, `mod.card` and concatenated source in `src/parts.txt` order.
- Build and test the install ZIP.

## Mount sizing

- Confirm `POKEDEX SIZES` is enabled by default.
- Compare a small mount (Rhyhorn/Fearow) with a large mount (Lapras/Dragonair/Gyarados).
- Confirm Gyarados is dramatically larger than Blastoise at 100.
- Change at least one flying, Ground and Surf species size while mounted; confirm the visual scale updates.
- Confirm the rider remains human-sized and its seat height follows the mount.
- Repeat in 2D, voxel orbit, `1ST` and `3RD` where the player card is visible.
- Confirm collisions, ledges, encounters and Surf transitions remain cell-based and unchanged.
- Reset defaults and confirm every species returns to 100.
