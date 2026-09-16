# {{Title}} — one line saying what this lab measures

*Companion paper to the interactive lab in `labs/{{slug}}/`. Overview
board: `overview.grafli`. Purpose: **{{purpose}}** — this is a lab
report, and the lab is the instrument. Started {{date}}. Annotate freely
with CriticMarkup.*

> Skeleton, not content. A research paper's load-bearing parts are the
> method, the records and the limitations; a lesson bolted onto the end
> serves neither reader. Delete this quote block and the italic guidance
> as you fill the sections in.

## The question

*Sharp enough to be answered by a NUMBER. If the answer is a paragraph,
the question is not ready yet.*

## What this lab can hold

*Answerability, stated BEFORE the method: which part of the question the
instrument can actually answer, and which part it cannot. A reduced
question stated up front is a result; a silently reduced one is a lie.*

## Method

| | |
|---|---|
| Swept | … |
| Held fixed | … |
| Seeds | 42 |
| Steps per run | 600 at 1/60 s |
| Scenario | `intro` |
| Objective | … |

Two scenarios at one seed are two noise realisations, not a controlled
comparison: a branch that draws no random numbers shifts the shared
stream for everything downstream. Sweep seeds, or say so.

## The model and its assumptions

*The arithmetic the lab implements, in pandoc math, at the level
implemented — not the textbook level.*

$$
\dot{x} = f(x, u)
$$

| Simplification | Expected effect on the result |
|---|---|
| … | … |

## Results

*Quote only what a record holds.* Every number below names the run record
it came out of; regenerate them all with

```sh
labs/{{slug}}/records/make.sh
```

and check the determinism claim with

```sh
labs/{{slug}}/records/make.sh --verify
```

| Scenario | Seed | Steps | Quantity | Value | ± | Record |
|---|---|---|---|---|---|---|
| intro | 42 | 600 | … | … | … | `records/intro-42.labrec` |

A number you cannot get out of a record is a missing probe, not a licence
to quote from the panel. Any change to the model, the sensors, the RNG
consumption pattern or the sampling invalidates every row — re-run
`make.sh` and re-read the table off the new files in the same commit.

## Limitations

*Where the answer stops being trustworthy. Be specific about the
boundary, not modest about the whole thing.*

## How to run it

```sh
./build/bin/claydojo --sbx labs/{{slug}}/Sandbox.qml
```

**Key map — every key the lab handles.** Keep this in sync with the
header comment in `Sandbox.qml`, the hint bar and the board.

| Key | Does |
|---|---|
| `1`–`9` | presets |
| `T` | guided tour · `Space`/`→` next · `←` back · `Esc` leave |
| `F` / `0` | frame the selection / reset the view |
| arrows · `WASD` | travel · `Shift`+arrows turn · `+`/`-` zoom |
| `Shift+R` | record a run |
| `Ctrl +/-/0` | text size |
| `?` | every key |

## Source map

- `labs/{{slug}}/Sandbox.qml:1` — the lab
- `labs/{{slug}}/strings.js:1` — every user-visible string, EN + DE

*Line numbers drift with every edit — re-check them as the last step
before handover.*
