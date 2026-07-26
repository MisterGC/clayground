# Sensor Fusion 101 — why a car trusts three liars

*Companion paper to the interactive lab in `labs/sensor-fusion-101/`.
Overview board: `overview.grafli`. Annotate freely with CriticMarkup —
remarks feed the next lab iteration.*

## The question

A car needs to know where it is. Every sensor it has is wrong in its own
way: GPS is **unbiased but noisy** (and dies in tunnels), wheel odometry
is **smooth but drifts without bound**, lidar against a known map is
**precise but conditional** (it needs mapped landmarks actually in view —
in range *and* not hidden). Sensor fusion is the art of combining wrongs
into one estimate that is better than any single source. This lab makes
that visible: the gold car is the truth, the purple pad is what odometry
believes, the blue pad is the fused estimate, and the glowing disc under
it is how unsure the filter admits to being.

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

That single equation *is* the lesson: a precise lidar fix (measured
$\sigma \approx 0.3\,\mathrm{m}$ with four landmarks in view) moves the
estimate almost all the way — gain 0.58 in the panel — while a GPS fix
worth $\pm 3.7\,\mathrm{m}$ only nudges it, gain 0.01. No sensor is
trusted; every sensor is *weighed*. And since $\sigma$ is what does the
weighing, a sensor that reports an over-optimistic $\sigma$ is far more
dangerous than a sensor that is merely imprecise — see the caveats under
"Measured results" for a live example of exactly that.

## Why the lidar needs a map

A lidar measures **where things are relative to the car** — ranges and
bearings to whatever surface reflects a beam. That is not a position. It
becomes one only when a **map** says *which surveyed object* each
detection is: given two identified landmarks, the car's position is the
point from which those measurements would look exactly like that.

So the lab treats the buildings as a **landmark map** (rings on the
ground mark the surveyed entries). Each tick the sensor keeps the entries
that are in `range` **and unoccluded** — a landmark behind another
building is not a measurement, however close it is — measures range and
bearing to each, and solves for position. Fewer than two observable
landmarks and there is no fix at all: not a flag, a consequence.

Both localisation sensors share one solver
(`labs/kits/sensor/trilateration.js`, weighted Gauss-Newton) and differ
only in what they anchor to:

| | anchors | measurements | extra unknown | 2D minimum |
|---|---|---|---|---|
| GPS | satellites (ephemeris) | range only | receiver clock offset | 3 |
| lidar | mapped landmarks | range **and** bearing | — | 2 |

Because the solver weights each row by $1/\sigma$, its covariance comes
out in metres² — so each sensor reports both a real $\sigma$ and a
geometry-only DOP. Two consequences are worth watching in the panels:
**bunched landmarks give a worse DOP than spread ones**, and **distant
landmarks are worse than close ones**, because bearing noise becomes
cross-range error that grows with range.

## Stated simplifications

- **Perfect data association**: every detection is matched to the right
  map entry for free. A real stack can mis-associate, and the failure
  mode that produces is a *gross* error, not extra noise — the single
  biggest omission here.
- Landmarks are **points**, not façades: this is landmark localisation,
  not scan matching against surfaces. The scan silhouette in the monitor
  is drawn from the same geometry but is *not* what the fix uses.
- Lidar heading is taken from the **odometry**, so odometry drift is felt
  in the lidar fix too — the two sensors are not independent, exactly as
  in a real stack.
- The map is assumed **perfectly surveyed**; real map error adds directly
  to the fix.
- Odometry is shown as an independent dead-reckoning baseline
  (scale bias + heading random walk), not fed into the filter — the
  contrast between the gray and cyan cars is the point.
- Satellites orbit a few tens of units up rather than 20 200 km; real
  geometry varies mildly, at this scale it varies visibly.
- The tunnel is a **structure in the world**, not a special case in the
  code: its walls sit in the same blocker list both sensors test against,
  so from inside it every satellite and every landmark is occluded and
  the filter runs on prediction alone.
- The filter is initialized at the true starting pose.
- Measurement noise is Gaussian and white; real sensors have bias and
  multipath structure.

## Measured results

60 simulated seconds, seed 42, default parameters, sampled at 20 Hz
(1200 samples):

| scenario | max err GPS | max err odometry | max err **fused** | mean err fused | max $\sigma$ |
|---|---|---|---|---|---|
| open-sky | 15.01 m | 3.66 m | **3.16 m** | 0.78 m | 0.33 m |
| tunnel | *see the caveat below* | | | | |

Readings: in open sky the fused estimate beats GPS by roughly a factor
of 5 while staying an order of magnitude tighter than its worst source,
and the uncertainty it reports (0.33 m) is consistent with the error it
actually makes (mean 0.78 m, so within about 2σ).

Two caveats, both honest and both open:

- **The tunnel row is withheld.** With the heading solved and no prior
  on it, two landmarks in a near-collinear arrangement admit a
  rotation-flipped second solution: a fix measured 30 m from truth while
  reporting $\sigma = 0.60\,\mathrm{m}$, which the filter then believed.
  A wilder one (374 m) was *harmless* because its $\sigma$ came out at
  17.6 m and the gain collapsed to 0.0003 — the difference between the
  two is the whole argument for reporting uncertainty honestly. The fix
  is a heading prior plus a residual gate; until then the tunnel numbers
  would document a bug rather than the physics.
- **Run-to-run reproducibility is currently not exact.** Sensors tick on
  the fixed sample grid, but the truth pose is a binding on the clock's
  *continuous* time, so a sample reads the pose wherever the last frame
  left it — and frame timing is wall-clock. Two same-seed runs therefore
  diverge from the first sample (measured: `errOdo` 0.163 vs 0.240 m at
  $t=0$). The numbers above are representative of a run, not bit-exact,
  until sampling reads the pose at the instant it claims.

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
- Watch the `LIDAR → MAP` panel through a corner: markers fill in as
  landmarks come into view, grey out when a building hides them, and the
  DOP moves with the *shape* of what is visible, not just the count.
- Shrink `lidarRange` to 8: most of the map falls out of view, the fix
  drops out on the sparse stretches, and GPS takes over the weighing.

## Run it

```bash
./build/bin/claydojo --sbx labs/sensor-fusion-101/Sandbox.qml
```

Keys follow the shared lab map, and `?` lists all of them in-app: `1-3`
presets · `T` guided flow · `C` chase/free camera · `M` the lidar → map
panel · `#` ground grid · `F` frame the car · `0` frame the city ·
arrows/`+`/`-` orbit · `⇧R` record CSV · `Esc` back to the car. Language
switches EN/DE top-right. Agents attach via `.clay/inspect/`
(`Lab.labInfo()`, probes `errGps`/`errOdo`/`errFused`/`uncertainty`).

## Source map

- Lab scene and wiring: `labs/sensor-fusion-101/Sandbox.qml:1`
- Track geometry: `labs/sensor-fusion-101/track.js:1`
- Kalman filter: `plugins/clay_algorithm/KalmanFilter2D.qml:1`
- Sensors: `labs/kits/sensor/GpsSensor.qml:1`,
  `labs/kits/sensor/OdometrySensor.qml:1`,
  `labs/kits/sensor/LidarSensor.qml:1`
- Shared localisation solver: `labs/kits/sensor/trilateration.js:1`
- Determinism/steppability: `plugins/clay_lab/SimClock.qml:1`

*Verified via the clay-crew inspector. What is confirmed: the solver
recovers position, clock bias and heading exactly on synthetic input
(13/13 headless assertions, including that a stale heading biases a fix
while its $\sigma$ keeps flattering it); the tunnel blackout is caused by
its walls rather than by a flag (47/47 samples inside: 0 satellites, 0
landmarks, no fix); and the open-sky numbers above come from a recorded
1201-sample run. What is NOT yet confirmed is bit-exact reproducibility —
see the caveats above.*
