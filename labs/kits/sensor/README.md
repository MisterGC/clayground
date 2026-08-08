# Sensor kit — localisation from anchors you can see

Three sensors a vehicle can carry, plus the solver two of them share. The
point of the kit is that **position error is produced, not dialled in**: a
fix degrades in a street canyon and dies in a tunnel because the world got
in the way, never because a flag was set.

Used by `labs/sensor-fusion-101/`. Checked by
`node labs/kits/sensor/sensor.test.js`.

## Model card

*A lab card in the sense of a spec sheet: what this kit is a model of, what
it deliberately is not, and therefore which questions it can be asked.*

### What it models

**Localisation from anchors with known positions.** Both the GPS and the
lidar sensor reduce to one problem — you know where the anchors are, you
measure something about each, you solve for where you must be standing —
and both run the same engine, `trilateration.js`: **weighted Gauss-Newton**
with weights `1/sigma`, so the covariance it returns is already in metres²
and needs no post-scaling. DOP is reported separately as
`posSigma / rangeSigma`: the geometry's own contribution, independent of how
good the ranging is.

| | anchors | measurements | extra unknown | 2D minimum |
|---|---|---|---|---|
| GPS | satellites | range only | receiver clock offset | 3 |
| lidar | mapped landmarks | range **and** bearing | — | 2 |

- **`GpsSensor`** — a receiver, not a noise generator. A drifting
  constellation (`gnss.js`, time-driven so it never touches the seeded RNG
  stream), a line-of-sight test against the world's blocker boxes,
  a pseudorange per visible satellite with per-range noise `sigmaM`, and a
  least-squares fix for x, y and the receiver's own clock offset. It reports
  `visibleCount`, `hdop` and `posSigma = sigmaM × hdop` — what *this* fix is
  worth, which is what a filter needs to weigh it.
- **`LidarSensor`** — landmark localisation against a **known map**. A lidar
  on its own measures where things are *relative to the car*; it becomes a
  position sensor only when a map says which surveyed object each detection
  is. Range **and** bearing to each identified landmark that is in `range`
  and unoccluded gives four constraints for three unknowns at two landmarks,
  so position *and* heading come out of the solve rather than being
  borrowed.
- **`OdometrySensor`** — dead reckoning: true motion deltas integrated
  through a scale bias (`scaleBias`, 1.02 by default) and a seeded heading
  random walk (`driftRate`, rad/√s). Smooth, and wrong without bound. It is
  the baseline the other two are judged against.
- **`Satellite3D`** — the sky, drawn: a marker per satellite and a link to
  the receiver, solid while that satellite is in the fix.

### Deliberate simplifications

Each of these is a decision, and each has a direction of effect:

- **Perfect data association.** Every detection is matched to the right map
  entry for free. A real stack mis-associates, and the failure that produces
  is a *gross* error, not extra noise. **The single biggest omission here** —
  results will be optimistic in exactly the cluttered scenes where a real
  system struggles most.
- **Landmarks are points, not façades.** This is landmark localisation, not
  scan matching against surfaces. A scan silhouette drawn from the same
  geometry is *not* what the fix uses.
- **The map is perfectly surveyed.** Real map error adds directly to the fix
  and is not represented at all.
- **Satellites orbit a few tens of units up**, not 20 200 km. Real geometry
  varies mildly over a minute; at this scale it varies visibly — which is the
  point in a classroom, and a distortion in a measurement.
- **No ionosphere, troposphere or multipath.** What *is* modelled is
  blockage, geometry and per-range noise. Real GNSS error is dominated by
  the terms that are missing.
- **Noise is Gaussian and white.** Real sensors carry bias and structure.
- **2D throughout.** Three visible satellites suffice here; real GPS needs
  four because it also solves the vertical.
- **Odometry is a dead-reckoning baseline**, not a fused input — the contrast
  is the lesson. Lidar heading, however, *is* taken from odometry
  (`assumedHeadingError`), so the two sensors are deliberately not
  independent, exactly as in a real stack.

### Where it stops being valid

- **Absolute accuracy numbers do not transfer.** With multipath, atmosphere
  and map error absent and association perfect, every error figure this kit
  produces is a lower bound. Use it to compare *conditions* and *weightings*,
  never to predict a real receiver's metres.
- **Near-collinear landmark geometry is a known failure.** With heading
  solved and no prior on it, two landmarks in a near-collinear arrangement
  admit a rotation-flipped second solution. Sometimes it comes with an honest
  sigma (harmless — the gain collapses) and sometimes it does not (a fix
  30 m out reporting 0.60 m). A heading prior plus a residual gate is the
  fix, and is not implemented.
- **Below the minimum anchor count there is no fix at all** — not a degraded
  one, not a flag. `minSats` (3) and `minLandmarks` (2) are cliffs.
- **The singular-geometry guard** in the solver returns nothing rather than a
  wrong answer; a study that treats "no fix" as a missing sample rather than
  as data will overstate availability.
- **A scenario change alters the noise realisation.** A sensor that produces
  no fix draws no random numbers, so switching a sensor off or occluding it
  shifts the shared seeded stream for everything downstream. Comparing two
  scenarios at one seed compares two different noise realisations — sweep
  seeds, or give each sensor its own stream first.

### What you can vary

| knob | on | meaning |
|---|---|---|
| `sigmaM` | GPS, lidar | per-**range** noise (not position error) |
| `rateHz` | GPS, lidar | fix rate; GPS staleness at speed usually dominates sigma |
| `satellites`, `blockers` | GPS | the sky and what stands in front of it |
| `minSats`, `antennaHeight` | GPS | availability cliff, line-of-sight origin |
| `landmarks` | lidar | **the map** — which objects are surveyed |
| `range`, `minLandmarks` | lidar | how far it sees, how little it needs |
| `bearingSigma` | lidar | angular noise; becomes cross-range error with distance |
| `solveHeading` | lidar | solve heading, or take the assumed one as truth |
| `driftRate`, `scaleBias` | odometry | heading random walk, distance bias |
| `enabled` | all | genuine sensor failure, distinct from occlusion |

The world itself is the other knob: a blocker box is a building or a tunnel,
and moving one changes availability and geometry together.

### What you can measure

`lastFix {x, y, t}`, `available`, `posSigma` and the geometry that produced
it (`hdop` for GPS, `dop` and `usedCount` for lidar), `visibleCount` and the
per-satellite `sky` visibility, the lidar's `hits` and `hidden` landmark
lists, and odometry's `estX`/`estY`/`headingErr`. Anything here is a one-line
`Probe`.

### Questions it can answer

- How much does *geometry* alone cost a fix, holding ranging noise fixed?
  (`hdop`, `dop` versus landmark spread and range.)
- What is a sensor's fix worth, and does a filter weight it accordingly?
  (`posSigma` against the realised error and the applied Kalman gain.)
- How fast does dead reckoning diverge, and how much of that does one fix a
  second recover?
- What happens when a sensor stops — and is the loss graceful or a cliff?
- Is a reported sigma honest? (Compare it against the realised error over
  a run; both are recordable.)

### Questions it cannot answer

- *"What accuracy will my receiver get downtown?"* — no multipath, no
  atmosphere, no real constellation. The absolute numbers are not physical.
- *"Will my SLAM stack lose track?"* — data association is free here, which
  is the thing that actually breaks.
- *"How does this behave at highway speed / over hours?"* — the timing model
  is a fixed 20 Hz sample grid over a minute-scale run, and there is no
  vehicle dynamics model at all.
- Anything about the vertical, attitude beyond planar heading, or map error.

## API

- `trilateration.js` — `solve(anchors, opts)`, the weighted Gauss-Newton
  engine; returns position, covariance and DOP, or nothing on singular
  geometry.
- `gnss.js` — `constellation(t, count, radius)`, deterministic and
  time-driven; line-of-sight and pseudorange helpers.
- QML: `GpsSensor`, `LidarSensor`, `OdometrySensor`, `Satellite3D`.
- `strings.js` — the kit's EN/DE vocabulary; a lab registers it first and may
  override it.

## Tests

```bash
node labs/kits/sensor/sensor.test.js
```

Covers the solver against synthetic input (position, clock bias and heading
recovered exactly), the honest-sigma cases, and the occlusion logic.
