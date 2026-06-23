# libslovian

A combat [Defold](https://defold.com/) utility library of reusable gameplay systems and helpers.

## What's inside

### Core

- **Class** — minimal inheritance system.
- **Settings** — observable user-preferences class with save/load.
- **StateModel** — observable game-meta state class with validators, dirty tracking, and pluggable serialization.
- **Codec** / **TableCodec** — integrity-protected table serialization.
- **Traits** — string↔id interner and bit-set signatures for trait tagging.
- **WeightedRandom** — one-pass weighted reservoir sampling.
- **Utils** — math, random-seed, permutation, and class-check helpers.

### Defold

- **Fragment system** — split game-object scripts into composable fragments with dependency-ordered callbacks. Includes `Fragment`, `FragmentsCollection`, `FsmFragment`, `DynamicFragment`, `DynamicModulesFragment`, plus `baseCollection` and `TraitsCollection` for managing groups of objects/traits.
- **FSMs** — `ScriptFsm`, `FsmFragment`, and `GuiFsm` for state-machine-driven logic in scripts, fragments, and GUI scripts.
- **GUI helpers** — `Bevel` (beveled panel shader helper), `Parallax`.
- **Camera** — `CameraUtilz` screen-to-world helpers.
- **Audio** — `music_manager` and `sound_manager` templates (configure URLs per project).
- **LiveUpdate** — generic `ContentManager` for downloading and mounting LiveUpdate archives.

## Conventions

- Lua modules are named `CapitalCamelCase`.
- Defold scripts are named `lowercase_with_underscores`.
- Project-specific values (app name, save file, sound URLs, codec secrets, validators) are always supplied by the game project, never hardcoded in the library.

## Installation

### As a Defold library dependency

Add the release ZIP URL to your `game.project` under `[project] dependencies`:

```ini
[project]
dependencies = https://github.com/Slovian/libslovian/releases/download/v0.1.0/libslovian.zip
```

The library code lives under the `libslovian/` folder, so require paths stay the same as when it is cloned locally.

### As a local clone

```bash
git clone https://github.com/Slovian/libslovian.git libslovian
```

Then require modules as needed:

```lua
local Settings = require("libslovian.core.Settings")
local FragmentsCollection = require("libslovian.defold.fragment.FragmentsCollection")
```

## License

See [LICENSE](./LICENSE).
