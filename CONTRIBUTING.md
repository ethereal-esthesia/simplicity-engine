# Contributing

Thanks for contributing to Simplicity Engine.

## Development Setup

1. Install CMake (3.21+), Ninja, and a C compiler.
2. Clone the repository.
3. Use the debug preset for local iteration:

```bash
cmake --preset debug
cmake --build --preset debug
```

## Build Types

- `Debug`: default development mode.
- `Release`: optimized runtime mode.

## Pull Requests

Before opening a PR:

1. Build both local presets:
   - `cmake --preset debug && cmake --build --preset debug`
   - `cmake --preset release && cmake --build --preset release`
2. If you touch container/build tooling, run:
   - `docker run --rm -it -v "$PWD:/workspace" simplicity-engine-build ./tools/build-in-container.sh`
3. Update `README.md` and/or `TESTING.md` when behavior or commands change.
4. Keep changes focused and explain rationale in the PR description.

## Coding Notes

- Prefer clarity over cleverness.
- Keep the initial runtime path simple and deterministic.
- Avoid introducing heavyweight dependencies without discussion.
