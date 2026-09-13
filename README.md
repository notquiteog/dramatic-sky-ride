# Dramatic Sky Ride

Dramatic Sky Ride adds controllable **Flight**, **Ground Ride** and **Visible Surf** mounts to Gen1Recomp. It works in native 2D, supports compatible voxel camera mods, Generation II mounts, Wild Skies interoperability, optional flying music, and animated **Pokemon Stadium 2** mounts generated locally from the player's own ROM through Crystal 251.

DSR remains the gameplay owner: movement, collision, altitude, progression, mounted state, rider placement and mount sizing stay inside Dramatic Sky Ride. Companion mods provide sprites, world rendering, airborne encounters, music or Stadium assets without taking over DSR's core mount logic.

## Quick start

### Required

- Gen1Recomp `>=0.1.69 <2.0.0`
- Dramatic Sky Ride

No third-party mod is required for native 2D Flight.

### Recommended 2D setup

For the currently validated setup, use **mfrtechconsult/PokePCFollowers** (`PokePCFollowers_VoxelMerge`) as the primary Pokemon sprite/follower provider.

**Wilds of Kanto is not part of the validated Dramatic Sky Ride support matrix yet.** Compatibility work is ongoing and will be released separately once the complete Gold/Gen2 path is verified.

Add **Wild Skies** for visible airborne Pokemon and aerial interceptions. **Wild Skies 1.9.0 or newer is required for Wild Skies on Pokémon Gold/Gen 2.** DSR owns the player's mount and flight state; Wild Skies independently owns sky ecology, time-of-day species, resident flocks, route-boundary persistence and its own flyer rendering. Add Crystal 251 or another compatible Gen II content provider if you want Johto Pokemon to exist in-game.

### Recommended voxel setup

- **Battle Art Voxel Fork** `>=1.7.6 <2.0.0` — recommended renderer;
- **Dramaless Shape** `>=1.6.4 <2.0.0` — supported alternative and the easiest current Stadium 2 import host.

Native 2D Flight does not require either renderer.

### Known issues

- HGSS-style overworld sprites can currently fail to display on the Generation II path. This is a known issue and a fix is planned for an upcoming release.
- Wilds of Kanto compatibility is still under development and is not currently supported.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Flight | `H` | `X` |
| Ground Ride | `G` in 2D/Battle Art, `J` with Dramaless | `Y` |
| Flight altitude | `Page Up` / `Page Down` | `R2` / `L2` |

Visible Surf uses the game's normal Surf movement and progression rules.

### Generation II quick testing

During the Generation II test phase, a temporary scientist NPC in **New Bark
Town** gives **Ho-Oh, Suicune, Raikou and Gyarados**. Ho-Oh receives Fly, and
Suicune and Gyarados receive Surf, so every Gen II mount type can be tested
immediately. Missing gifts are placed in the party first and then in the PC.

For a faster progression-free test, set `SETTINGS VIEW = ADVANCED`, then set
`BADGE CHECKS = OFF`. This helper NPC and the relaxed badge option are intended
for testing only.

## Settings

DSR now includes a simplified settings view:

- `SETTINGS VIEW = SIMPLE` shows the main user-facing controls only;
- `SETTINGS VIEW = ADVANCED` exposes the complete configuration surface;
- `SIZE OVERRIDES = EDIT` reveals the per-species mount-size controls only when you need them.

Hidden settings are never reset. Switching between Simple and Advanced only changes what the menu displays.

See **[Settings](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/SETTINGS.md)** for the full reference.

## Supported mounts

**Flight — 16:** Charizard, Pidgeot, Fearow, Golbat, Aerodactyl, Articuno, Zapdos, Moltres, Dragonair, Dragonite, Noctowl, Crobat, Xatu, Skarmory, Lugia, Ho-Oh.

**Ground Ride — 17:** Arcanine, Rapidash, Dodrio, Rhyhorn, Rhydon, Kangaskhan, Tauros, Snorlax, Meganium, Girafarig, Ursaring, Donphan, Stantler, Raikou, Entei, Suicune, Tyranitar.

**Visible Surf — 8:** Blastoise, Tentacruel, Gyarados, Lapras, Feraligatr, Mantine, Kingdra, Lugia.

Suicune is a special amphibious Ground Ride mount and can transition between land and water without dismounting once normal Surf progression is available.

## Pokemon Stadium 2 mounts

Set `MOUNT RENDERER = STADIUM 3D` to use animated Stadium 2 models for the active DSR mount when a valid Crystal 251 Stadium cache is available.

DSR does **not** include Pokemon Stadium 2 ROM data or Nintendo model assets. The player supplies a compatible legally obtained ROM, and Crystal 251 generates a local cache under `crystal_251/stadium2/`.

See **[Pokemon Stadium 2 setup](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/STADIUM2.md)** for the complete import and renderer guide.

## Documentation

- **[Installation](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/INSTALLATION.md)** — recommended setups and installation order
- **[Settings](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/SETTINGS.md)** — Simple/Advanced modes and every option group
- **[Compatibility](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/COMPATIBILITY.md)** — Wilds, PokéPC, Wild Skies, Battle Art, Dramaless, Crystal 251, Stadium companions and music packs
- **[Pokemon Stadium 2](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/STADIUM2.md)** — cache generation, `READY`, Battle Art vs Dramaless, reimport and troubleshooting
- **[Troubleshooting](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/TROUBLESHOOTING.md)** — common symptoms and diagnostic steps
- **[Technical reference](https://github.com/mfrtechconsult/dramatic-sky-ride/blob/main/docs/TECHNICAL.md)** — ownership model, inter-mod surfaces and Stadium architecture

## Credits

Dramatic Sky Ride interoperates with work from the Gen1Recomp community, including Battle Art/Dramatic Shape, Dramaless Shape, Crystal 251, Stadium overworld model projects, Wilds of Kanto, PokéPC Followers, Wild Skies, OTF Player Switcher and compatible music packs.

See the compatibility and technical pages for project-specific notes.

## Bug reports

Include the following whenever possible:

- Gen1Recomp version;
- DSR version;
- selected mount and renderer;
- Battle Art or Dramaless version when relevant;
- Crystal 251 version if Stadium 2 is involved;
- whether the Stadium 2 cache already existed before launch;
- Wilds/PokéPC/Wild Skies setup;
- relevant DSR diagnostic log lines.
