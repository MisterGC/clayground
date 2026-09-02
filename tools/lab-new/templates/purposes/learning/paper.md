# {{Title}} — one line saying what this lab is for

*Companion paper to the interactive lab in `labs/{{slug}}/`. Overview
board: `overview.grafli`. Purpose: **{{purpose}}** — this is a study
path, written while working the thing out. Started {{date}}. Annotate
freely with CriticMarkup — remarks feed the next iteration.*

> Skeleton, not content. Every section below is here because a learning
> paper that skips it stops being a study path. Delete this quote block
> and the italic guidance under each heading as you fill them in; delete
> a heading only if you can say why it does not apply.

## The question

*What are you trying to understand, in two or three sentences? Sharp
enough that you would recognise the answer.*

## What I expected

*Write the prediction down BEFORE the first run — this is the section
that cannot be reconstructed later, and the whole reason a learning
paper is worth writing. Being wrong here is the point.*

## The model, at the level I can hold it

*The actual arithmetic the lab implements, in pandoc math, at the level
you understand it — not the textbook's level.*

$$
\dot{x} = f(x, u)
$$

*Then the simplifications, each one declared:*

| Simplification | Why it is acceptable | What it costs |
|---|---|---|
| … | … | … |

## Worked examples

*One subsection per thing you can redo in the lab: which scenario, which
knob to turn, and the number to watch.*

### intro

*Press `1`. Turn … . Watch … .*

## Where the intuition broke

*The surprises, in your own words. Keep the wrong version visible.*

## Measured results

*Quote only what a record holds.* Every number below names the run
record it came out of; regenerate them all with

```sh
labs/{{slug}}/records/make.sh
```

| Scenario | Quantity | Value | Record |
|---|---|---|---|
| intro | … | … | `records/intro-42.labrec` |

A number you cannot get out of a record is a missing probe, not a licence
to quote from the panel: add the probe, re-record, then quote. Any change
to the model, the RNG consumption or the sampling invalidates these — re-run
`make.sh` and re-read the table in the same commit.

## Still open

*The questions the lab did not settle. A short honest list beats a
confident wrong one.*

## How to run it

```sh
./build/bin/claydojo --sbx labs/{{slug}}/Sandbox.qml
```

**Key map — every key the lab handles.** Keep this in sync with the
header comment in `Sandbox.qml`, the hint bar and the board; a paper that
says `R` when the lab means `Shift+R` sends a reader to destroy their work.

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
