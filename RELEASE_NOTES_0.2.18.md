# Dramatic Sky Ride 0.2.18 — Pre-sandbox restoration

This release restores the complete Dramatic Sky Ride 0.2.11 runtime, the last version before sandbox compatibility was introduced in 0.2.12.

## Restored behavior

- Restores the original pre-sandbox Flight, Ground Ride and Visible Surf implementation.
- Restores the legacy filesystem-backed follower/provider discovery path.
- Restores the full Stadium 2 mount animation and cache implementation.
- Restores continuous camera-relative movement in Gold's first- and third-person flight views.
- Removes the sandbox-era Open Sky, sandbox-provider and bundled PokePC fallback changes from the active runtime.

## Compatibility note

This version intentionally requests the historical `filesystem` permission and targets the same game versions as 0.2.11. Its runtime and assets match 0.2.11 exactly except for release metadata.
