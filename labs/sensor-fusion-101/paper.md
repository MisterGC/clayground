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

That single equation *is* the lesson, and the record `open-sky-42` holds
the arithmetic: over 1200 fixes the lidar reported $\sigma$ between 0.26
and 0.74 m (mean 0.36 m) and earned a mean gain of **0.21**, peaking at
1.00 when the geometry was good; GPS reported 3.58 to 9.03 m (mean
4.26 m) and earned a mean gain of **0.0015**. The same filter weighs one
sensor about 140 times as heavily as the other, and nothing anywhere says
"trust the lidar" — every sensor is *weighed*, by the $\sigma$ it hands
in.

Which is why a sensor that reports an over-optimistic $\sigma$ is far
more dangerous than a sensor that is merely imprecise. The record
`tunnel-42` has one of each: the lidar's reported $\sigma$ runs up to
20.98 m on a bad landmark geometry — and that fix is *harmless*, because
the gain collapses with it. It is the fix that is wrong while reporting a
small $\sigma$ that moves the estimate, and the caveats under "Measured
results" describe the one case where that still happens here.

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

Every number below comes out of a committed **run record** in
`records/`, and each row names the record it is read from. Regenerate all
three, and with them this table:

```bash
labs/sensor-fusion-101/records/make.sh
```

60 simulated seconds, seed 42, default parameters, sampled every 0.05 s
(1201 samples), stepped at 1/60 s:

| scenario | record | max err GPS | max err odometry | mean err **fused** | max err **fused** | mean $\sigma$ |
|---|---|---|---|---|---|---|
| open-sky | `open-sky-42` | 13.66 m | 21.41 m | **0.76 m** | 3.09 m | 0.24 m |
| tunnel | `tunnel-42` | 33.50 m | 12.15 m | **2.47 m** | 15.08 m | 0.49 m |
| lidar-out | `lidar-out-42` | 18.17 m | 7.53 m | **15.28 m** | 28.55 m | 3.72 m |

Readings, in the order they matter:

- **In open sky the fusion works.** The fused estimate is 0.76 m out on
  average against a GPS fix that is 4.84 m out on average and an odometry
  belief that has drifted 18.8 m by the end of the minute: an order of
  magnitude better than either source, which is the whole claim of the
  lab.
- **In the tunnel it degrades gracefully rather than failing.** Three
  passes through the blackout show up as three humps in `errFused`
  (mean per 6 s: 0.26, 1.49, **5.77**, 0.86, 0.81, **3.85**, **3.63**,
  0.66, 1.09, **6.21**), peaking at 15.08 m at $t = 37.3\,\mathrm{s}$.
  Both humps the run has time to recover from are back under a metre in
  the following six seconds (0.86 and 0.66); the third is still in
  progress when the record ends. Running on prediction alone for a few
  seconds costs metres, not the track.
- **With lidar out, fusion is worse than the GPS it is fusing.** Mean
  fused error 15.28 m against a mean GPS fix error of 5.34 m. That is not
  noise, it is model error: a constant-velocity filter corrected once a
  second cannot hold a car going round a bend, so it consistently cuts
  the corner and each 1 Hz fix only pulls it part of the way back. Raise
  `gpsRate` and the row improves; it is an honest limitation of the
  motion model, not of the sensor. The gain tells the same story from the
  other side: with lidar gone, GPS's mean gain rises from 0.0015 to
  **0.33** — the filter now leans on the sensor it barely used, because
  there is nothing else.
- **A blackout makes the filter humble, briefly.** In `tunnel-42` the GPS
  gain peaks at 0.042, an order of magnitude above its open-sky peak:
  while prediction alone inflates $P$, the next fix out of the tunnel is
  worth much more. That is the covariance doing its job.

**The filter is over-confident, in every scenario.** This is the most
important reading in the table and the one the earlier version of this
paper got wrong. In open sky it reports $\sigma \approx 0.24\,\mathrm{m}$
while making a 0.76 m error — the error exceeds $2\sigma$ in **53 %** of
samples, and in `lidar-out` in **88 %** of them. A well-tuned filter
should be outside $2\sigma$ about 5 % of the time. The cause is visible
in the model section: process noise is a single scalar (`processNoise:
1.2`) covering an unmodelled turn rate. Read the glowing disc as "how
sure the filter *claims* to be", never as an error bar you can trust.

Two caveats on reading the table:

- **Scenarios are not comparable at one seed.** A sensor that produces no
  fix also draws no random numbers, so switching lidar off or putting a
  tunnel in the way shifts every later draw in the shared stream. That is
  why `errOdo` differs across the rows (21.41 / 12.15 / 7.53 m) although
  odometry is untouched by all three changes: each row is a different
  noise realisation, not a different odometry. Compare *within* a row, or
  give each sensor its own stream first.
- **The rotation-flip in the lidar fix is still open.** With the heading
  solved and no prior on it, two landmarks in a near-collinear
  arrangement admit a rotation-flipped second solution: a fix 30 m from
  truth reporting $\sigma = 0.60\,\mathrm{m}$, which the filter then
  believes. A wilder one (374 m) was *harmless* because its $\sigma$ came
  out at 17.6 m and the gain collapsed to 0.0003 — the difference between
  the two is the whole argument for reporting uncertainty honestly. The
  fix is a heading prior plus a residual gate. The tunnel row is no
  longer withheld for it, but it is a reason the tunnel peak is a ceiling
  rather than a physical constant.

**Reproducibility is now exact, and this is what changed.** The earlier
version of this paper reported that two same-seed runs diverged from the
first sample. They did: the truth pose is a binding on the clock's
*continuous* time, and a frame is a wall-clock interval, so a live run
samples the pose wherever the last frame happened to leave it. The
records above are not produced by a live run — `make.sh` stops the frame
ticker and advances the clock in fixed 1/60 s steps, which makes sim time
a pure function of the step count. Two runs of the same scenario and seed
now produce **byte-identical** records:

```bash
labs/sensor-fusion-101/records/make.sh --verify
```

One residual offset comes with that, and it explains why `errOdo` and
`errFused` both start at exactly 0.100 m: a sample labelled $t$ is taken
just after the step that crossed it, so the pose it reads is up to one
step (1/60 s, 0.1 m at 6 m/s) ahead of the label.

A detail worth noticing in the live plot: the GPS error is a **sawtooth**,
not white noise — at 1 Hz and 6 m/s the car outruns each fix by up to
6 m before the next one arrives. GPS error here is dominated by
*staleness*, not by $\sigma$; raising `gpsRate` flattens the teeth,
raising `gpsSigma` only lifts their base. Note that `errGps` measures the
error of the *most recent* fix, so during a blackout it ages rather than
disappearing — that, not a sudden loss of accuracy, is the 33.50 m in the
tunnel row.

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
arrows/`+`/`-` orbit · `⇧R` record a run · `Esc` back to the car. Language
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
- The records this paper quotes: `labs/sensor-fusion-101/records/`
- How they are produced: `labs/sensor-fusion-101/records/make.sh:1`
- The record format: `plugins/clay_lab/record.js:1`

*Verified via the clay-crew inspector. What is confirmed: the solver
recovers position, clock bias and heading exactly on synthetic input
(13/13 headless assertions, including that a stale heading biases a fix
while its $\sigma$ keeps flattering it); the tunnel blackout is caused by
its walls rather than by a flag (47/47 samples inside: 0 satellites, 0
landmarks, no fix); every number in the results table is read out of a
committed record rather than out of a memory of a run; and bit-exact
reproducibility now holds for stepped runs — `make.sh --verify` compares
two same-seed records byte for byte and all three scenarios pass. What is
NOT confirmed is that a live, frame-driven session reproduces those
numbers: it does not, and it is not meant to.*
