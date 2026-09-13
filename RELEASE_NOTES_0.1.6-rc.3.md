# Dramatic Sky Ride 0.1.6-rc.3 — Wilds test build

Development test build from `compat/wilds-of-kanto`. Do not publish as stable yet.

## Focus fixes after in-game Wilds testing

- Hide follower entities by default while any DSR mount is active, including visible/native Surf.
- Add `MOUNT FOLLOWERS`, default OFF. When enabled, other followers may remain visible but the Pokemon currently used as the mount stays hidden.
- Reassert 1ST/3RD camera-driven body facing after late Wilds updates, targeting the Lugia and Skarmory direction regression.
- Preserve Suicune Ground Ride across seamless route connections instead of falling back to the generic Surf presentation.
- Keep Suicune as visual owner through water battle return so another visible Surf mount cannot flash during remount.
- Track Dramatic Deep Dive alpha.7 diagnostic travel-only mode correctly in the full-stack CI.

## Test focus

1. Wilds follower suppression on flight, Ground Ride and Surf.
2. `MOUNT FOLLOWERS` enabled: other followers visible, current mount hidden.
3. Lugia and Skarmory direction in 1ST/3RD.
4. Suicune land -> water -> route connection -> water/land without visual fallback.
5. Suicune water battle -> overworld without another aquatic mount flashing.

Stadium 3D is not part of this regression pass.
