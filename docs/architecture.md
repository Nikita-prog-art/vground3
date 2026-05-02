# VGround Architecture

VGround is a small V prototype for a Minecraft/Zelda/Stardew-like game.

The current executable is `cmd/vground`. It loads `mods/core.vgmod`, builds a registry, creates a chunked demo world, then runs mobs in separate V runtime tasks.

## Frontends

Frontends are selected with `--frontend`.

- `terminal`: working deterministic event log and ASCII renderer. This is the debugging frontend.
- `gui`: reserved slot that currently delegates to `terminal`.

The simulation is independent from the frontend. A GUI renderer can consume the same mob events and world snapshots later.

## Mod Model

`core.vgmod` is JSON with a `.vgmod` extension. It declares blocks, items, mobs and runtime slots.

Content ids are namespaced as `mod:id`, for example `core:grass`.

Definitions can be declarative only, or reference hooks:

- V hook: `mods/core/scripts/behaviors.v:slime_bounce`
- C hook: `mods/core/native/crop_growth.c:vground_crop_growth_tick`
- reserved future runtimes: Lua and JVM slots are present in the runtime registry

The prototype does not dynamically compile or load mod code yet. It validates and exposes the hook metadata so the ABI can be implemented without changing content manifests.

## Concurrency

The scheduler is selected with `--scheduler`. The default is `go`, following V's current concurrency docs.

- `go`: each mob runs in its own lightweight V runtime task through `go`.
- `spawn`: each mob runs in its own OS thread through `spawn`.
- `green`: mobs are stepped as cooperative tasks on the frontend thread. This is useful for deterministic debugging and leaves room for a real fiber runtime later.

The world is split into fixed-size chunks. Every chunk owns a `sync.Mutex`. Mob logic calls `World.try_step`, which locks the destination chunk, reads the target block and updates per-cell visit counters before unlocking.

This is intentionally conservative. It gives a clear place to evolve toward:

- chunk-level jobs
- actor mailboxes
- green-thread scheduling
- native FFI hooks
- sandboxed external runtimes
