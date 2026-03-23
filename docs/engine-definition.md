# Simplicity Engine Spec: What Is an Engine?

## Purpose
Define what makes `simplicity-engine` an engine (not just a library or app scaffold), and establish a minimum bar for architecture decisions.

## Engine Definition
An engine is a reusable runtime platform for building multiple applications/games, where the engine owns runtime orchestration and exposes stable extension points for app/game code.

## Engine vs Library
- A library provides callable functionality (functions/types/components).
- An engine provides the runtime model:
  - lifecycle and main loop ownership,
  - subsystem orchestration (render/input/audio/timing),
  - resource and asset management,
  - platform abstraction,
  - tooling/debuggability hooks.

## Minimum Engine Criteria (v0)
`simplicity-engine` should meet all of the following:

1. Runtime Ownership
- Clear application lifecycle (`init`, `update`, `render`, `shutdown`).
- Deterministic frame/tick scheduling policy.

2. Core Subsystems
- Rendering abstraction with backend fallback strategy.
- Input abstraction independent of window backend specifics.
- Time/frame pacing API.
- Asset/resource loading with cache boundaries.

3. Platform Layer
- Window/event/runtime integration abstracted behind engine interfaces.
- Behavior differences across platforms documented with fallback policies.

4. Extensibility Surface
- Public API where user code plugs into engine lifecycle safely.
- Stable contracts between engine core and app/game modules.

5. Observability
- Structured logging categories.
- Basic runtime diagnostics (frame timing, event traces, backend info).

## Non-Goals (Current Stage)
- Full editor/tool suite.
- Full scene editor or scripting VM.
- Advanced content pipeline beyond initial import/load/cache.

## Acceptance Checklist
Before calling `simplicity-engine` an engine milestone:
- [ ] A sample app is built by consuming engine APIs (not engine internals).
- [ ] Runtime can swap/choose at least one backend strategy with fallback.
- [ ] Lifecycle and subsystem interfaces are documented and versioned.
- [ ] Core diagnostics are available without source patching.

