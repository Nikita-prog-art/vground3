# VGround Architecture

VGround is a small V prototype for a Minecraft/Zelda/Stardew-like game.

The current executable is `cmd/vground`. It loads `mods/core.vgmod`, builds a registry, creates a chunked demo world, then runs mobs through the selected scheduler.

## Frontends

Frontends are selected with `--frontend`.

- `terminal`: working deterministic event log and ASCII renderer. This is the debugging frontend.
- `gui`: reserved slot that currently reuses the terminal renderer through the shared frame-consumer contract.

The simulation is independent from the frontend. A GUI renderer can consume the same simulation frames and world snapshots later.

Frontends start simulation through `start_simulation`. Low-level consumers can read `SimEvent` values through `SimulationRun.next_event`; renderers normally use `SimulationRun.next_frame`, which applies each event to `SimulationState` and returns a `SimulationFrame`.

`SimulationFrame` contains the event, the current `SimulationSnapshot`, and a `render_due` flag computed by `RenderCadence`. That keeps render cadence in the simulation/view layer instead of duplicating global-tick logic in every frontend. `SimulationState` exposes snapshots for renderers, so frontends read snapshots instead of owning their own mob-position maps.

`run_frame_frontend` is the common frontend runner. It starts a live simulation or reads a replay, then feeds `SimulationFrame` values into a `SimulationFrameConsumer`. Frontends implement `begin`, `consume` and `finish`; scheduler details and replay plumbing stay outside renderer code.

## Replay

`--replay-out path` writes a replay v1 file as newline-delimited JSON. The first line is a header with schema version, mod ids/versions/runtimes, scheduler settings, render cadence, demo world hash, event count and final snapshot hash. The remaining lines are the consumed `SimEvent` stream.

`--replay-in path` reads that stream, validates v1 metadata when present, rebuilds `SimulationFrame` values by applying events to `SimulationState`, and renders those frames through the selected frontend. Legacy event-only NDJSON files still load, but they do not carry compatibility metadata.

`--replay-verify path` is a non-rendering command mode. It reads a v1 replay, rebuilds the final `SimulationSnapshot`, hashes it, and fails if the hash does not match the header.

Replay stores events, not world chunks. The current demo world is deterministic, so replaying with the same loaded content reproduces snapshots and terminal rendering without rerunning mob AI or scheduler timing.

## Mod Model

`core.vgmod` is TOML with a `.vgmod` extension. It declares blocks, items and mobs.

Content ids are namespaced as `mod:id`, for example `core:grass`.

Definitions can be declarative only, or reference hooks:

- Mod runtime: `runtime = "v"` at the top of the mod.
- Hook entries are relative to the mod directory, for example `scripts/behaviors.v:slime_bounce`.
- Future mods can use other runtime names such as `c`, `lua` or `jvm`; the registry treats runtime as a per-mod contract.

The prototype does not dynamically compile or load mod code yet. It validates and exposes the hook metadata so the ABI can be implemented without changing content manifests.

Mob AI already goes through a static `BehaviorRegistry` adapter. Behavior handlers are registered by mod id and runtime; for `core` with `runtime = "v"`, manifest hook entries such as `scripts/behaviors.v:slime_bounce` map to registered V functions that mirror `mods/core/scripts/behaviors.v`. The registry validates hook entries directly. The older `behavior = "..."` field remains as a deprecated fallback when no mob AI hook exists.

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
