# Stadium 2 3D Mounts — Stable Technical Guide

This document applies to Dramatic Sky Ride 0.2.0 and newer.

## Scope

DSR can replace only the **active DSR mount** with a native animated Pokemon Stadium 2 model while keeping Flight, Ground Ride, Visible Surf, altitude, collisions, camera integration, rider display and mount sizing under DSR control.

No Pokemon Stadium 2 model data or ROM is shipped with DSR. Models are read from DSM packs generated locally by Crystal 251 from the player's own compatible Stadium 2 ROM.

## Cache contract

Expected cache:

- root: `crystal_251/stadium2`
- marker: `crystal_251/stadium2/pack.info`
- format: `C2DSM10`
- species: 251
- variants: normal + shiny

DSR rejects incomplete/stale caches and detects the historical one-frame static-cache failure.

## Renderer, importer and ROM UI are separate capabilities

A mod may provide one or more of these:

1. **Voxel renderer** — Voxel3D, matrices, shadows and world presentation.
2. **Stadium import host** — the full Stadium module family Crystal 251 needs to build DSM packs.
3. **ROM-selection surface** — a menu/file-picker action.

### Dramaless / Dramatic Shape

These expose the full Stadium import module family and can host Crystal 251's Stadium 2 builder.

### Battle Art

Battle Art is supported for rendering an existing Stadium 2 cache. Its current public tree does not contain the complete importer module family, so first-time cache creation still needs a compatible full import host.

### STADIUM_OVERWORLD_MODELS

DSR capability-probes the installed companion rather than assuming every build behaves identically. When DSR native Stadium 2 owns the active mount, the generic companion mount tag is suppressed so both mods do not render the same mount. Companion wild/follower/UI behavior remains available.

## Persistent import UI

DSR 0.2.0 fixes a post-import lifecycle bug from the alpha builds.

A valid `READY` cache no longer causes the Crystal bridge bootstrap to return before UI/provider attachment. On every boot where a compatible full import host is available, DSR reattaches the bridge even when the cache already exists.

Expected behavior:

- before import: `STADIUM 2 ROM = IMPORT`
- during build: `BUILDING`
- after import: `READY`
- after restarting with the same healthy cache: still `READY`

Restoring the UI never invalidates a healthy cache.

## Animation pipeline

DSR reads real DSM skeletal clips and:

- validates the decoded skeleton/model;
- uses provider `StadiumRig` where available;
- otherwise uses DSR's interpolated/anchored skinning fallback;
- drives pose/skin from the render path so provider update-order differences cannot freeze visible mounts;
- keeps animated DSM material/effect frames synchronized;
- applies the same mount-motion matrix to the model and shadow.

## Mount-motion coverage

- Flight: 16 roles
- Ground Ride: 17 roles
- Visible Surf: 8 roles
- Suicune: one extra amphibious-water helper owned by Ground Ride

Use `stadium3DMountMotion.audit()` to verify coverage and matrix attachment.

## Recommended validation species

Flight:
- Charizard
- Dragonair
- Skarmory
- Lugia

Ground:
- Rapidash
- Dodrio
- Tauros
- Raikou
- Suicune
- Snorlax / Tyranitar for restrained heavy profiles

Surf:
- Tentacruel
- Gyarados
- Lapras
- Mantine
- Kingdra
- Lugia

## Diagnostics

Useful public APIs:

- `stadium3DNative.cacheStatus()`
- `stadium3DNative.modelInfo(species)`
- `stadium3DAnimationCacheGuard.inspect()`
- `stadium3DCrystalBootstrap.status()`
- `stadium3DCrystalBootstrap.retry()`
- `stadium3DProviderRig.active()`
- `stadium3DFallback.interpolated`
- `stadium3DEffects.status()`
- `stadium3DLiveAnimation.stats(dex)`
- `stadium3DRenderClock.stats(dex)`
- `stadium3DMountMotion.audit()`
- `stadium3DProviderInterop.status()`
- `stadium3DDiagnostics.snapshot(species)`
- `stadium3DDiagnostics.log(species)`

## Fallback hierarchy

1. Native Stadium 2 model using provider StadiumRig when available.
2. DSR interpolated/anchored DSM skinning fallback.
3. Compatible STADIUM_OVERWORLD_MODELS companion when appropriate.
4. Legacy Stadium behavior where supported.
5. DSR 2D mount rendering.

A failed Stadium model path must not make the mount disappear.
