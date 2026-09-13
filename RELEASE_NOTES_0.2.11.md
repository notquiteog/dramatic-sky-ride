## Dramatic Sky Ride 0.2.11

This release promotes the validated Generation II Wild Skies integration and restores continuous camera-relative movement in Gold's 1ST/3RD flight views.

### Added / Fixed

- Added validated Wild Skies 1.9+ interoperability on Pokémon Gold / Generation II.
- Fixed aerial Wild Skies interception so physically colliding with a visible flyer reliably starts the intended wild battle.
- Preserved Wild Skies' own sky ecology, flyer population, species/level ownership and battle-rest behavior.
- Restored continuous camera-relative movement in Gold's 1ST and 3RD flight cameras instead of the native four-direction quantization.
- Preserved route connection handling, flight altitude, camera follow and existing Gen 1 behavior.

### Support status

- Wilds of Kanto is **not supported yet** by this stable release. Compatibility work remains in development and will be released once the Gold/Gen2 integration is fully validated.
- The currently validated sprite/follower path is the maintained `mfrtechconsult/PokePCFollowers` setup.

### Known issue

- HGSS-style overworld sprites can currently fail to display on the Generation II path. This is a known issue and is planned to be fixed in an upcoming release.

The attached ZIP is launcher-ready and is reconstructed and compiled with LuaJIT after packaging before publication.
