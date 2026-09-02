# Hydraulics 101 — one line saying what this lab teaches

*Companion paper to the interactive lab in `labs/hydraulics-101/`. Overview
board: `overview.grafli`. Purpose: **teaching** — this is a lesson
plan, and the guided flow is the primary artifact; this paper is its
script. Started 2026-09-02. Annotate freely with CriticMarkup.*

> Skeleton, not content. A teaching paper that keeps stopping to ask the
> reader a question is a learning paper in the wrong clothes. Delete this
> quote block and the italic guidance as you fill the sections in.

## The question

*What does the lab answer, in two sentences, from the learner's side?*

## The misconception it targets

*Stated as the belief a learner ARRIVES with, in their words, not as the
correction. If you cannot write the wrong belief down, the lesson has no
target and the flow has no shape.*

## The demonstration sequence

*Which scenario, what to change, what to ask — in order, one row per
beat. This table and the `FlowStep`s in `Sandbox.qml` are the same
sequence and must not drift apart.*

| Beat | Scenario / action | Ask them | Flow step |
|---|---|---|---|
| 1 | `intro` | … | `hydraulics_101-intro` / `intro` |
| 2 | … | … | … |
| 3 | … | … | … |

## The moment the number contradicts the belief

*Name the reading and the value it lands on. This is the whole lesson;
everything before it is setup and everything after is consolidation.*

## The takeaway

*One sentence a learner could repeat afterwards.*

## When they ask…

*The two or three follow-ups that always come, with answers.*

- **…?** …
- **…?** …

## Measured results

*Quote only what a record holds.* Every number the lesson names must come
out of a committed run record; regenerate them all with

```sh
labs/hydraulics-101/records/make.sh
```

| Scenario | Quantity | Value | Record |
|---|---|---|---|
| intro | … | … | `records/intro-42.labrec` |

The flow's `expect` predicates carry the same measured values, so a
drifted lab breaks its own lesson loudly instead of teaching a wrong
number. Any change to the model or the sampling invalidates both — re-run
`make.sh`, re-read the table and re-check the predicates in one commit.

## Stated simplifications

*Labs teach concepts, and a simplified model is a feature provided every
simplification is declared — here AND in the app.*

| Simplification | Why it is acceptable | What it costs |
|---|---|---|
| … | … | … |

## How to run it

```sh
./build/bin/claydojo --sbx labs/hydraulics-101/Sandbox.qml
```

Press `T` for the guided tour — that is the lesson.

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

- `labs/hydraulics-101/Sandbox.qml:1` — the lab
- `labs/hydraulics-101/strings.js:1` — every user-visible string, EN + DE

*Line numbers drift with every edit — re-check them as the last step
before handover.*
