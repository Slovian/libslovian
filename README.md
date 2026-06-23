# libslovian

A compact, [Defold](https://defold.com/)-first Lua utility library of reusable gameplay systems and helpers. Extracted from real projects (including *RTGambit*) and designed to be **inherited and configured**, not edited in place.

## What's inside

### Core

- **Class** — minimal inheritance system.
- **Settings** — observable user-preferences class with save/load.
- **StateModel** — observable game-meta state class with validators, dirty tracking, and pluggable serialization.
- **Codec** / **TableCodec** — integrity-protected table serialization.
- **BehaviorTree** — hierarchical resolver for grid/tactical behavior trees.
- **WeightedRandom** — one-pass weighted reservoir sampling.
- **Utils** — math, random-seed, permutation, and class-check helpers.

### Defold

- **Fragment system** (`Fragment`, `FragmentsCollection`) — split game-object scripts into composable fragments with dependency-ordered callbacks.
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

Add this repository as a dependency in your Defold project, or clone it into a `libslovian/` folder next to your own source.

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
