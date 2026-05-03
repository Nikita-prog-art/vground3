# VGround Architecture

VGround is a small V prototype for a Minecraft/Zelda/Stardew-like game.

The current executable is `cmd/vground`. It loads `mods/core.vgmod`, builds a registry, creates a chunked demo world, then runs mobs through the selected scheduler.

## Frontends

Frontends are selected with `--frontend`.

- `terminal`: working deterministic event log and ASCII renderer. This is the debugging frontend.
- `gui`: reserved slot that currently delegates to `terminal`.

The simulation is independent from the frontend. A GUI renderer can consume the same mob events and world snapshots later.

Frontends start simulation through `start_simulation`, consume `SimEvent` values through `SimulationRun.next_event`, and apply them to `SimulationState`. `SimulationState` exposes `SimulationSnapshot` values for renderers, so frontends read snapshots instead of owning their own mob-position maps.

## Mod Model

`core.vgmod` is TOML with a `.vgmod` extension. It declares blocks, items and mobs.

Content ids are namespaced as `mod:id`, for example `core:grass`.

Definitions can be declarative only, or reference hooks:

- Mod runtime: `runtime = "v"` at the top of the mod.
- Hook entries are relative to the mod directory, for example `scripts/behaviors.v:slime_bounce`.
- Future mods can use other runtime names such as `c`, `lua` or `jvm`; the registry treats runtime as a per-mod contract.

The prototype does not dynamically compile or load mod code yet. It validates and exposes the hook metadata so the ABI can be implemented without changing content manifests.

## Concurrency

The scheduler is selected with `--scheduler` and parsed into the `Scheduler` enum. The default is `go`, following V's current concurrency docs.

- `go`: each mob runs in its own lightweight V runtime task through `go`.
- `deterministic`: mobs are stepped as cooperative tasks on the frontend thread. This is useful for reproducible debugging and leaves room for a real fiber runtime later.

The world is split into fixed-size chunks. Every chunk owns a `sync.Mutex`. Mob logic calls `World.try_mob_step`, which locks the source and destination chunks in deterministic order, checks block solidity and mob occupancy, moves the occupant id, and updates per-cell visit counters before unlocking.

This is intentionally conservative. It gives a clear place to evolve toward:

- chunk-level jobs
- actor mailboxes
- deterministic scheduling
- native FFI hooks
- sandboxed external runtime adapters
