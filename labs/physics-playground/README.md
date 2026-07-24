# Physics Playground

The P1 reference lab for `Clayground.Lab`: rigid-body boxes under tunable
gravity, restitution and friction — watch energy dissipate and stacks
settle, live-plotted.

Run:

```bash
./build/bin/claydojo --sbx labs/physics-playground/Sandbox.qml
```

- Sliders (top right): `gravity`, `restitution`, `friction`, `boxCount`
- Scenarios: `1` tower collapse · `2` box rain · `3` single drop
  (each resets the seeded clock — same seed, same run)
- `R` toggles CSV recording (`physics-playground-run.csv`)
- Probes: `kineticEnergy`, `avgHeight`, `moving` — plotted bottom,
  queryable via the inspector (`Lab.labInfo()`)

Things to try: set `restitution` to 1 and drop a single box (`3`) — does
it bounce forever? Why not quite? Crank `gravity` to 30 with `rain` and
watch the kinetic-energy spikes sharpen.
