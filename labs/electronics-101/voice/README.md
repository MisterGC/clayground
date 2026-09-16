# Narration audio

Pre-rendered professor narration for the guided flows. The compressed
`en/*.m4a` files ship with the lab; the `*.wav` masters they are cut from
are rendered per machine and gitignored.

## Regeneration

Rendered by the local text-to-speech project at `~/dev/eval/local_tts`
(Chatterbox multilingual, on device, no API):

```
cd ~/dev/eval/local_tts
.venv/bin/python speak.py --file <line.txt> --voice voices/prof_en_v2.wav \
    --preset professor --seed 7 --out <name>.wav
afconvert -f m4af -d aac -b 48000 <name>.wav <name>.m4a
```

One file per invocation (~7 s model load each). `--seed 7` makes a render
reproducible. Each language needs its own reference clip; German has none
rendered yet, so DE narrates in text only.

## File naming

- `en/<key>.m4a` - one clip per step of the LED flow, for the steps the
  professor narrates whole (`empty`, `wire`, `flip`, `values`, `try`).
- `en/<key>-<n>.m4a` - one clip per spoken LINE of a directed LED step
  (`battery`, `led`, `resistor`, `lit`, `why`); `n` counts the say cues of
  that step's performance script from 0.
- `en/logic-<key>.m4a` - one clip per step of the logic flow ("From one
  transistor to XOR"), all fourteen steps.

## Spoken forms

The on-screen line is not the line to speak: units are read out (`mA` ->
"milliamps", `V` -> "volts", `Ω` -> "ohms"), em-dashes become commas, and
anything that only works for the eye is rewritten for the ear. The exact
texts rendered:

- `battery-0`: This is the cell. It pushes: 4.5 volts between its two pads.
- `battery-1`: The gold pad is the plus side.
- `led-0`: The LED. It only conducts one way.
- `led-1`: And only above about 2 volts, its forward voltage.
- `lit-0`: There it is.
- `lit-1`: 5.1 milliamps flow, and the LED glows.
- `resistor-0`: And a 470 ohm resistor.
- `resistor-1`: Without it the LED would take all the current it can get and die. This is its seatbelt.
- `why-0`: Why 5.1 milliamps? The cell offers 4.5 volts, the LED eats about 2.1 of them, and the rest, 2.4 volts, falls across the resistor.
- `why-1`: 2.4 volts over 470 ohms is 5.1 milliamps. The resistor sets the current.
- `logic-adder`: Two of them reading the same two inputs, and you have arithmetic: SUM is A ex-or B, CARRY is A and B. Both switches on, and it reads sum zero, carry one, which is how binary writes one plus one equals one zero.
- `logic-and`: Now a gate. Two transistors in series, the series circuit again, with the switches made of silicon. The current has to get past both of them.
- `logic-andtask`: Switch both inputs on.
- `logic-both`: Now the other one as well. The NAND node collapses to almost nothing, the fifth transistor is cut off, and the lamp goes out, with more current available than ever.
- `logic-chip`: So nobody builds it twice. Everything on that last board is sold as one package: five pins, and the two on the short sides are the supply, a chip needs feeding like anything else. This one is doing exactly the ex-or you just wired by hand.
- `logic-chiptask`: Check it: turn exactly one input on.
- `logic-cost`: Five transistors, eight resistors and a lamp, for one bit of a decision. A phone holds billions of them. That is what this part bought.
- `logic-gain`: Read the two numbers. The meter in the base lead shows 0.8 milliamps; the lamp draws 9.8, twelve times as much, and only because twelve times is all the lamp asks for. This transistor would pass a hundred times its base current. The ring at its foot is green: it is fully switched on, and the lamp, not the transistor, is what limits the current now.
- `logic-meet`: This is a transistor. Three legs: collector on the left, emitter on the right, base facing you, the board says which is which. A small current into the base lets a much larger one through the other two.
- `logic-or`: Put the same two in parallel and either one is a way through. That is OR, the parallel circuit, doing logic.
- `logic-switch`: Your turn: close the switch, so a current can reach the base.
- `logic-switchit`: And the package is not committed. Select it and pick another function, this one is now a NAND, and the table was re-measured, not re-typed. Six gates, one part, and no rewiring.
- `logic-xor`: Ex-or is the awkward one: exactly one, never both. No such part exists. It is A or B, and not, A and B. So the board now holds the OR pair you just built, a NAND made of two more in series, and a fifth transistor that the NAND cuts off when both inputs go high.
- `logic-xortask`: Turn exactly one input on.

The five whole-step LED clips were rendered from the on-screen strings in
`../strings.js` (`flow.led-basics.<key>`), unchanged except the rules above.
