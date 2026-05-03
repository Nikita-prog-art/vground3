# vground3

Prototype of a moddable survival RPG sandbox in V.

Run the terminal frontend:

```sh
./v/v run cmd/vground -- --frontend terminal --ticks 12
```

Run the deterministic scheduler:

```sh
./v/v run cmd/vground -- --scheduler deterministic --ticks 12
```

Run tests:

```sh
./v/v test vground
```

The core content lives in the TOML manifest `mods/core.vgmod`. See `docs/architecture.md` for the current engine shape.
