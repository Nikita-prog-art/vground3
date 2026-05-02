# vground3

Prototype of a moddable survival RPG sandbox in V.

Run the terminal frontend:

```sh
./v/v run cmd/vground -- --frontend terminal --ticks 12
```

Run the cooperative green-task scheduler:

```sh
./v/v run cmd/vground -- --scheduler green --ticks 12
```

Run OS-thread actors for comparison:

```sh
./v/v run cmd/vground -- --scheduler spawn --ticks 12
```

Run tests:

```sh
./v/v test vground
```

The core content lives in the TOML manifest `mods/core.vgmod`. See `docs/architecture.md` for the current engine shape.
