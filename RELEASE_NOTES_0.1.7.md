# Dramatic Sky Ride 0.1.7

## Highlights

- Added optional compatibility with **OTF Player Switcher** (`otf-player-switcher`). Mounted rider art now follows the selected player character without making OTF a dependency.
- OTF character changes can refresh the rider during Flight, Ground Ride and Visible Surf. During Flight, Page Up / Page Down remain reserved for DSR altitude control; outside Flight, OTF keeps its normal shortcuts.
- Added a high-detail **PokeMMO mount renderer** for Wilds of Kanto. When Wilds is explicitly set to its PokeMMO sprite style, DSR reads the native 32/64 px source atlas instead of enlarging the generated 16 px runtime walker sheet.
- Corrected native PokeMMO apparent sizing by measuring a stable shared opaque crop, removing transparent source padding before the normal DSR Pokédex/user scale is applied.
- Added built-in canonical Generation II height fallbacks so Johto mounts such as Suicune, Raikou, Entei and Lugia keep coherent Pokédex-proportional sizing even when the active Gen2 content provider does not expose height fields.
- Improved flat **2D Flight** over tall buildings: automatic safety climbs remain authoritative internally for collision and gameplay, but no longer make the mount/rider sprite visibly jump in the top-down renderer. Manual altitude changes, takeoff and landing remain visible.
- Added a defensive source-loader boundary normalization so optional late compatibility chunks cannot fail to compile because two semicolon chunk boundaries meet.

## Compatibility

- **Wilds of Kanto OR mfrtechconsult/PokePCFollowers** remains the normal supported sprite/follower-provider setup; use one, not both.
- **Battle Art Voxel Fork** remains the recommended voxel / 1ST / 3RD companion. **Dramaless Shape** remains a supported alternative.
- **Wild Skies 1.4.1+** remains strongly recommended for visible airborne Pokémon and aerial interceptions.
- OTF Player Switcher is entirely optional. DSR behaves as before when it is absent.
- The PokeMMO high-detail path is entirely optional and activates only when Wilds is installed and its PokeMMO sprite style is selected. Other Wilds sprite styles retain their existing rendering path.

## Known limitations

- With `GROUND FOLLOWERS` enabled, the active Ground Ride mount may still appear in the follower trail.
- With Wilds of Kanto, Suicune may briefly show the ordinary Surf mount during post-battle return on water.
- The optional Stadium renderer remains experimental and is not part of the validated 0.1.7 highlights.

The attached ZIP is launcher-ready with `manifest.json` at the archive root and is validated before publication.
