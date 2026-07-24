# Sensor Fusion 101 — why a car trusts three liars

*Companion paper to the interactive lab in `labs/sensor-fusion-101/`.
Overview board: `overview.grafli`. Annotate freely with CriticMarkup —
remarks feed the next lab iteration.*

## The question

A car needs to know where it is. Every sensor it has is wrong in its own
way: GPS is **unbiased but noisy** (and dies in tunnels), wheel odometry
is **smooth but drifts without bound**, lidar against known landmarks is
**precise but conditional** (needs landmarks in range). Sensor fusion is
the art of combining wrongs into one estimate that is better than any
single source. This lab makes that visible: the gold car is the truth,
the gray car is what odometry believes, the cyan car is the fused
estimate, and the glowing disc under it is how unsure the filter admits
to being.

## The estimator

The lab uses a constant-velocity Kalman filter
(`plugins/clay_algorithm/KalmanFilter2D.qml`) with state
$\mathbf{x} = [x, y, v_x, v_y]^T$.

Prediction advances the state with the motion model and grows the
uncertainty:

$$
\mathbf{x}_{k|k-1} = F\,\mathbf{x}_{k-1}, \qquad
P_{k|k-1} = F P_{k-1} F^T + Q, \qquad
F = \begin{bmatrix} 1&0&\Delta t&0 \\ 0&1&0&\Delta t \\ 0&0&1&0 \\ 0&0&0&1 \end{bmatrix}
$$

Every sensor delivers a position measurement $\mathbf{z}$ with its own
standard deviation $\sigma$ ($R = \sigma^2 I$). The update weighs the
measurement against the prediction by their uncertainties:

$$
K = P H^T (H P H^T + R)^{-1}, \qquad
\mathbf{x}_k = \mathbf{x}_{k|k-1} + K(\mathbf{z} - H\,\mathbf{x}_{k|k-1})
$$

That single equation *is* the lesson: a precise lidar fix
($\sigma = 0.5\,\mathrm{m}$) moves the estimate almost all the way; a
sloppy GPS fix ($\sigma = 3\,\mathrm{m}$) only nudges it. No sensor is
trusted — every sensor is *weighed*.

## Stated simplifications

- Lidar is modeled as landmark scan-matching that directly yields a
  position fix with noise `sigmaM` when any landmark is in `range` —
  no per-ray point cloud (the full spinning-lidar model exists in
  `examples/neoncity/lidar.js` and is planned for the sensor kit).
- Odometry is shown as an independent dead-reckoning baseline
  (scale bias + heading random walk), not fed into the filter — the
  contrast between the gray and cyan cars is the point.
- The tunnel blocks GPS (radio) *and* lidar (bare walls); inside it the
  filter runs on prediction alone.
- The filter is initialized at the true starting pose.
- Measurement noise is Gaussian and white; real sensors have bias and
  multipath structure.

## Measured results

60 simulated seconds, seed 42, default parameters, sampled at 20 Hz
(1200 samples; deterministic — the run is reproducible bit-for-bit):

| scenario | max err GPS | max err odometry | max err **fused** | final err fused | max $\sigma$ |
|---|---|---|---|---|---|
| open-sky | 14.95 m | 12.72 m | **2.92 m** | 1.57 m | 0.71 m |
| tunnel | 26.21 m | 7.29 m | **13.84 m** | 0.82 m | 2.30 m |

Readings: in open sky the fused estimate beats both sources by roughly a
factor of 4–5. In the tunnel the filter loses all corrections and its
error grows on prediction alone (up to 13.8 m at the exit) — but the
uncertainty disc grows honestly with it ($\sigma$ 0.71 → 2.30 m), and
one fix after the exit collapses both. An estimator that *knows* when it
is lost is the second half of the lesson.

A detail worth noticing in the live plot: the GPS error is a **sawtooth**,
not white noise — at 1 Hz and 6 m/s the car outruns each fix by up to
6 m before the next one arrives. GPS error here is dominated by
*staleness*, not by $\sigma$; raising `gpsRate` flattens the teeth,
raising `gpsSigma` only lifts their base.

## Things to try

- Crank `gpsSigma` to 10 in open-sky: the scatter explodes, the cyan car
  barely reacts — lidar dominates the weighing.
- Kill lidar (`3`): now the same GPS noise visibly wobbles the estimate.
- Set `odoDrift` to 0.2 and watch the gray car leave the map — then
  remember many "indoor robots" have exactly this sensor suite.
- Slow GPS to 0.2 Hz with lidar out: uncertainty breathes between fixes.

## Run it

```bash
./build/bin/claydojo --sbx labs/sensor-fusion-101/Sandbox.qml
```

Keys: `1` open-sky · `2` tunnel · `3` lidar-out · `T` tour · `R` record
CSV. Agents attach via `.clay/inspect/` (`Lab.labInfo()`, probes
`errGps`/`errOdo`/`errFused`/`uncertainty`).

## Source map

- Lab scene and wiring: `labs/sensor-fusion-101/Sandbox.qml:1`
- Track geometry: `labs/sensor-fusion-101/track.js:1`
- Kalman filter: `plugins/clay_algorithm/KalmanFilter2D.qml:1`
- Sensors: `labs/kits/sensor/GpsSensor.qml:1`,
  `labs/kits/sensor/OdometrySensor.qml:1`,
  `labs/kits/sensor/LidarSensor.qml:1`
- Determinism/steppability: `plugins/clay_lab/SimClock.qml:1`

*Verified via the clay-crew inspector: two 3600-step runs from the same
seed produce identical probe series; the numbers above are from those
runs.*
