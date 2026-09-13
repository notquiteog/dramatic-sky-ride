# Dramatic Sky Ride 0.2.4

## Generation II compatibility

Dramatic Sky Ride now declares Generation II support and can be used in Gold with native 2D Flight, Ground Ride and Visible Surf mounts.

- Gold's live player now renders the active mount and rider correctly.
- Ho-Oh Flight, Raikou Ground Ride, Suicune's seamless land/water ride and Gyarados Visible Surf are available for the current test pass.
- Ground-to-Flight switching no longer leaves the Ground mount on the flying mount.
- Flight crosses authored route/city connections, including connections whose landing is blocked for ordinary walking.
- Ground Ride can climb authored ledges in reverse while ordinary walls, NPCs, warps and water remain protected.
- Flight water landings enter Gold's native Surf state, display the selected water mount and exit correctly at the shore.
- Generation II mount sizes use the same Pokedex-relative scale pipeline as Generation I.

## Quick testing

A temporary NPC in New Bark Town gives Ho-Oh, Suicune, Raikou and Gyarados, including the required FLY and SURF moves. Badge requirements can be disabled in Dramatic Sky Ride's advanced settings for rapid testing.

## Rendering scope

The validated Generation II path in this release is native 2D. Voxel and Stadium presentation remain dependent on compatible companion mods becoming available for the Gen2 runtime; DSR falls back to 2D when those capabilities are absent.

## Installation

The attached ZIP is launcher-ready with `manifest.json` at its root. PokePCFollowers or another compatible sprite provider is recommended for the complete mount art roster.
