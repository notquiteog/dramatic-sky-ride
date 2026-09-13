# Dramatic Sky Ride — Gen 2 / Gold Beta Testing

This checklist is for the **unverified Gen1Recomp++ / Gold compatibility beta** built from `agent/gen2-gen1recomp-plus-compat`.

The normal repository manifest remains conservative until this checklist has been exercised on a real Gold boot. Use the `dramatic-sky-ride-gen2-beta` CI artifact for the test build; that ZIP enables both Gen 1 and Gen 2 without changing the source manifest.

## 1. Boot sanity

- Start Gold with only Dramatic Sky Ride enabled first.
- Load or start a game and walk normally before mounting.
- Open/close the Start menu and DSR settings.
- Confirm no input lock, invisible player, permanent Surf pose, or boot error.

**Pass:** ordinary Gold gameplay is unchanged while DSR is idle.

## 2. Flight progression

Test one supported flying mount first, then at least one Johto-specific mount such as Noctowl, Crobat, Skarmory, Lugia, or Ho-Oh.

- Without STORM Badge: flight must be refused when badge checks are enabled.
- With STORM Badge: flight can start.
- With `REQUIRE FLY` enabled: the selected mount must know FLY, unless another mod intentionally grants eligibility through `fieldmove.eligibility`.
- Take off, change altitude, boost, cross a map connection, and land.

**Pass:** no Kanto THUNDERBADGE rule appears on Gold; normal movement is restored after landing.

## 3. Ground Ride

Test one ordinary land mount and one Johto-specific land mount.

- Start Ground Ride.
- Move, turn, gallop/boost where available, cross a normal map connection, stop the ride.
- Enter and finish a battle while mounted.

**Pass:** mount remount/cleanup works and Gold movement returns to normal afterwards.

## 4. Suicune — critical Gold test

Gold uses `World.playerState` for Surf traversal, not Gen 1's `player.surfing` flag. This beta contains a dedicated bridge for that state machine.

### Progression refusals

- No SURF user in party: Suicune must not enter water.
- SURF user but no FOG Badge with badge checks enabled: Suicune must not enter water.

### Normal amphibious traversal

- Start Suicune on land.
- Walk from land directly into water.
- Move several cells on water.
- Return directly to land.
- Repeat the transition in another direction.

**Pass:** the Ground Ride visual remains Suicune throughout; no generic Surf mount replaces it and the player never becomes stuck in Surf state.

### Map connection

- Cross a map connection where the destination landing cell is water.
- Cross back if possible.

**Pass:** the connection remains seamless and Suicune retains water traversal.

### Battle continuity

- While Suicune is on water, trigger a battle.
- Finish the battle normally.

**Pass:** Suicune is restored on water after battle and can continue moving without a Red/Chris Surf-pose leak or input lock.

## 5. Visible Surf

Test at least one regular visible Surf mount; Johto candidates include Feraligatr, Mantine, Kingdra, and Lugia.

- Start Surf normally.
- Move and cross a connection.
- Trigger and finish a battle.
- Return to land.

**Pass:** normal Visible Surf still works independently from Suicune's Ground Ride water path.

## 6. Wild Skies

If Wild Skies is installed:

- Fly through an airborne encounter and confirm the intended battle starts.
- Confirm ordinary ground encounters do not incorrectly trigger while DSR is airborne.
- Land and confirm ordinary encounters work again.

The beta uses the shared `encounter.species` hook instead of the Gen 1-only `BattleState.newWild` factory.

## 7. Optional visual providers

Only after the base test is stable, add the optional providers you normally use:

- Wilds of Kanto / compatible follower sprite provider
- PokePCFollowers
- Dramatic Shape or Battle Art where applicable
- Stadium Overworld Models
- Crystal 251 / Stadium 2 cache

**Pass:** missing or incompatible 3D data falls back rather than preventing DSR from running.

## 8. Save/reload safety

- Save on land after using DSR, reload, and walk normally.
- If Gold allows saving at the chosen water position, test a save/reload after Surf separately.
- Stop all rides before the final save and confirm no transient mount state persists incorrectly.

## Minimum report if something fails

Please capture:

1. Gold/Gen1Recomp++ build or commit if visible.
2. DSR beta artifact/build commit.
3. Installed optional mods.
4. Mount species and action that failed.
5. Whether the failure occurs before or after a battle/map connection.
6. Screenshot or log excerpt if available.

A single reproducible failure is more useful than testing every item after the game has entered a broken state.
