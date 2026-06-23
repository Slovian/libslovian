# Release Notes

## v0.1.0

Initial release of libslovian.

### Core

- `Class` — minimal inheritance system.
- `Settings` — observable user-preferences with save/load.
- `StateModel` — observable game-meta state with validators, dirty tracking, and pluggable serialization.
- `Codec` / `TableCodec` — integrity-protected table serialization.
- `Traits` — string↔id interner and bit-set signatures.
- `RPGStatsSheet`, `RPGStatsBook`, `RPGCounters`, `RPGCounterDefinitions` — additive/multiplicative stats and resource counters.
- `WeightedRandom` — one-pass weighted reservoir sampling.
- `Utils` — math, random-seed, permutation, and class-check helpers.

### Defold

- **Fragment system** — `Fragment`, `FragmentsCollection`, `FsmFragment`, `DynamicFragment`, `DynamicModulesFragment`, `BaseCollection`, `TraitsCollection`.
- **FSMs** — `ScriptFsm`, `GuiFsm`, `FsmFragment`.
- **GUI** — `Bevel`, `Parallax`.
- **Audio** — `music_manager` and `sound_manager` templates.
- **Camera** — `CameraUtilz` screen-to-world helpers.
- **LiveUpdate** — `ContentManager` for downloading and mounting LiveUpdate archives.
