# Stadium 2 Mount Motion — DSR 0.2.0

## Design rule

Pokemon Stadium 2 does not expose a trustworthy shared overworld `walk`, `run`, `fly` or `swim` animation contract. Its context slots are battle-oriented. DSR therefore does **not** invent generic per-bone locomotion mappings and does not reuse arbitrary attack animations as fake walking/running.

Instead, DSR keeps each Pokemon's genuine Stadium skeletal animation and adds a morphology-aware presentation layer driven by the real mount state.

## Motion model

### Flight

- skeletal playback cadence follows movement;
- forward travel adds pitch;
- climb/dive adds vertical pitch response;
- turns add banking;
- boost can increase cadence/presentation intensity.

### Ground Ride

- movement/gallop changes skeletal playback cadence;
- body bob and forward lean are tuned by morphology;
- turns add restrained response;
- fast quadrupeds/equines/runner birds are more expressive;
- heavy bipeds remain deliberately calmer.

### Visible Surf

- idle buoyancy remains visible at rest;
- travel changes cadence and pitch;
- turns add water roll;
- serpentine/ray-shaped swimmers receive stronger response than heavy swimmers.

### Suicune

Suicune remains a Ground Ride mount even when it runs over water. It has a dedicated internal `water` presentation but is not counted as a ninth Visible Surf mount.

## Complete role coverage

There are **41 normal mount-role entries**.

### Flight — 16

Charizard, Pidgeot, Fearow, Golbat, Aerodactyl, Articuno, Zapdos, Moltres, Dragonair, Dragonite, Noctowl, Crobat, Xatu, Skarmory, Lugia, Ho-Oh.

### Ground Ride — 17

Arcanine, Rapidash, Dodrio, Rhyhorn, Rhydon, Kangaskhan, Tauros, Snorlax, Meganium, Girafarig, Ursaring, Donphan, Stantler, Raikou, Entei, Suicune, Tyranitar.

### Visible Surf — 8

Blastoise, Tentacruel, Gyarados, Lapras, Feraligatr, Mantine, Kingdra, Lugia.

## Runtime audit

`stadium3DMountMotion.audit()` checks:

- 16 Flight profiles;
- 17 Ground profiles;
- 8 Visible Surf profiles;
- the Suicune amphibious helper;
- malformed profile data;
- render-clock attachment;
- model-matrix attachment;
- shadow-matrix attachment.

A technically present profile is not considered sufficient if the model transform hook is missing.

## Current limitation

Ground/Surf are still presentation-based rather than true authored overworld gait libraries. A future species-specific locomotion clip should only be enabled after that exact Stadium source clip has been visually verified as a credible walk/run/swim cycle for that Pokemon.

The `idle_alt` slot used by some Stadium overworld companion logic is not automatically treated as a better gait: Crystal 251's current generic Stadium 2 context mapping can point `idle_alt` back to the same decoded idle clip.
