# Dramatic Sky Ride 0.2.0

## Native animated Pokemon Stadium 2 mounts

DSR 0.2.0 promotes the Stadium 2 mount renderer to the stable branch.

- Renders the active Flight, Ground Ride or Visible Surf mount from Crystal 251's locally generated Stadium 2 DSM cache.
- Uses real Stadium 2 skeletal tracks with render-path pose/skin updates and interpolation.
- Supports the complete current DSR roster: 16 Flight roles, 17 Ground Ride roles and 8 Visible Surf roles, plus Suicune's amphibious-water presentation.
- Keeps DSR authoritative for movement, collision, altitude, progression, rider state and sizing.
- Keeps the trainer as a separate rider rather than replacing the player with a Pokemon model.
- Includes animated DSM effect-frame support for compatible Stadium materials/effects.

## Mount motion

- Adds morphology-aware Flight pitch, climb/dive response and banking.
- Adds tuned Ground Ride cadence, body bob/lean and turn response.
- Adds Visible Surf buoyancy, pitch and water-turn roll.
- Fixes Suicune's missing amphibious Stadium water profile.
- Keeps heavy bipeds restrained instead of fabricating exaggerated generic locomotion.
- Does not misuse arbitrary Stadium battle attacks as fake walk/run/swim animations.

## Crystal 251 Stadium 2 import

- Supports Crystal 251 `>=0.9.13` and its corrected Stadium 2 pose decoder.
- Keeps cache generation separate from rendering/provider selection.
- Dramaless/Dramatic Shape can provide the complete Stadium import module family.
- Battle Art can render an existing Stadium 2 cache even though it does not currently contain the complete importer family itself.
- Fixes the post-import UI regression: once a Stadium 2 cache is `READY`, DSR still reattaches Crystal's bridge on later boots so `STADIUM 2 ROM` remains available for status/reimport instead of disappearing.
- A healthy existing cache is never deleted or rebuilt merely to restore the importer UI.

## Provider and companion interoperability

- Adds capability-based separation between voxel renderer, Stadium import host and ROM-selection surface.
- Supports Battle Art, Dramaless and compatible legacy/provider stacks without hard-coding one renderer as the only path.
- Adds explicit `STADIUM_OVERWORLD_MODELS` interoperability so the companion can continue handling wild Pokemon, followers and its own UI while DSR remains the sole owner of the active native Stadium 2 mount.
- Prevents duplicate rendering of the same active DSR mount when both native Stadium 2 and a Stadium overworld companion are installed.

## Existing DSR features retained

- Native renderer-independent 2D Flight.
- Generation II Flight/Ground/Surf mounts.
- Wilds of Kanto and maintained PokePC Followers compatibility.
- Wild Skies aerial encounters.
- Optional high-detail PokeMMO mounted sprites when Wilds uses that sprite style.
- OTF Player Switcher rider compatibility.
- Optional FRLG/HGSS/LGPE Flying Music integration.
- Suicune seamless land/water Ground Ride.

## Installation

The attached `dramatic-sky-ride-0.2.0.zip` is launcher-ready: `manifest.json` is at the ZIP root.

DSR does not include Pokemon Stadium 2 ROM/model assets. Stadium 2 models are generated locally from the player's own compatible ROM through Crystal 251.
