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
  professor narrates whole (`empty`, `voltage`, `resistance`, `switch`,
  `wire`, `flip`, `current`, `values`, `volts`, `ohm`, `power`, `try`).
- `en/<key>-<n>.m4a` - one clip per spoken LINE of a directed LED step
  (`battery`, `led`, `resistor`, `lit`, `why`); `n` counts the say cues of
  that step's performance script from 0.
- `en/logic-<key>.m4a` - one clip per step of the logic flow ("From one
  transistor to XOR"), all eighteen steps.

## Spoken forms

The on-screen line is not the line to speak: units are read out (`mA` ->
"milliamps", `V` -> "volts", `Ω` -> "ohms"), a decimal is written out in
words where a render garbled the digits ("2.4" -> "two point four"; checked
by transcribing the clip back), em-dashes become commas, and
anything that only works for the eye is rewritten for the ear. The exact
texts rendered:

- `empty`: Let's build the simplest circuit that lights an LED. Watch, I'll place the parts on the board.
- `voltage`: Voltage is the push that drives charge round a circuit, measured in volts. This cell pushes with 4.5 volts from one pad to the other.
- `resistance`: Resistance is how hard a part makes it for charge to get through, measured in ohms. This resistor has 470 ohms.
- `switch`: And a switch. Open, it breaks the loop; closed, it joins it. It starts open.
- `wire`: Now the loop: cell to switch, switch to LED, LED through the resistor and back to the cell. Current needs a closed loop.
- `flip`: Your turn: click the switch to close the circuit.
- `current`: What flows round a closed loop is current: how much charge passes each second, measured in amps. The LED gets five point one milliamps, thousandths of an amp, and the plot draws it.
- `values`: Read it off the board: every part carries the same 5.1 milliamps. Same current everywhere in one loop, that is a series circuit.
- `volts`: Now the voltages: about 2.1 volts across the LED and 2.4 volts across the resistor. Together they use up the cell's 4.5 volts.
- `ohm`: That is Ohm's law: current is voltage divided by resistance. Two point four volts over 470 ohms is five point one milliamps. The resistor sets the current.
- `power`: The plot now shows power: voltage times current, the energy a part turns into light and heat each second, in watts. The LED: two point one volts times five point one milliamps, about 11 milliwatts; the plot rounds it to zero point zero one watts.
- `try`: Try it yourself: select the resistor and drag its slider. Less resistance, more current, brighter LED, until it gives up.
- `battery-0`: This is the cell, the part that drives everything on this board.
- `battery-1`: The gold pad is its plus side.
- `led-0`: The LED. It only conducts one way.
- `led-1`: And only above about 2 volts, its forward voltage.
- `resistor-0`: And a resistor.
- `resistor-1`: Without it the LED would let through as much as the cell can push, and burn out. This is its seatbelt.
- `lit-0`: There it is.
- `lit-1`: The loop is closed, and the LED glows.
- `why-0`: Why five point one milliamps? The LED keeps about two point one volts for itself, as LEDs do.
- `why-1`: The two point four volts left over is what pushes the current through the resistor.
- `logic-meet`: This is a transistor. A small current into one of its legs lets a much larger one through the other two.
- `logic-legs`: Three legs: the collector at the back, toward the LED, the emitter at the front, toward you, and the base on the left, where the current from the switch comes in. The board says which is which.
- `logic-switch`: Your turn: close the switch, so a current can reach the base.
- `logic-gain`: Read the two numbers. The meter in the base lead shows 0.8 milliamps; the LED draws 9.8 milliamps, twelve times as much.
- `logic-limit`: Only twelve times, because that is all the LED asks for: this transistor would pass a hundred times its base current. The ring at its foot is green: it is fully on, and the LED now limits the current.
- `logic-and`: Now a gate. Two transistors in series, the series circuit again, with the switches made of silicon. The current has to get past both of them.
- `logic-andtask`: Switch both inputs on.
- `logic-or`: Put the same two in parallel and either one is a way through. That is OR, the parallel circuit, doing logic.
- `logic-xor`: Ex-or is the awkward one: exactly one, never both. No single transistor does that, so it is built from the gates we have.
- `logic-nand`: Two words first. NOT turns a signal round: on becomes off, off becomes on. NAND is not and: its output is off only when both inputs are on.
- `logic-xorbuild`: So ex-or is, A or B, and not, A and B. The board holds the OR pair from the last board, a NAND made of two more in series, and a fifth transistor that the NAND cuts off when both inputs are on.
- `logic-xortask`: Turn exactly one input on.
- `logic-both`: Now the other one as well. The NAND node collapses to almost nothing, the fifth transistor is cut off, and the LED goes out, with more current available than ever.
- `logic-cost`: Five transistors, nine resistors and an LED, for one bit of a decision. A phone holds billions of them. That is what this part bought.
- `logic-chip`: So nobody builds it twice. Everything on that last board is sold as one package: five pins, and the two on the short sides are the supply, a chip needs feeding like anything else. This one is doing exactly the ex-or the five transistors did.
- `logic-chiptask`: Check it: turn exactly one input on.
- `logic-switchit`: And the package is not committed. Select it and pick another function, this one is now a NAND, and the table was re-measured, not re-typed. Six gates, one part, and no rewiring.
- `logic-adder`: Two of them reading the same two inputs, and you have arithmetic: SUM is A ex-or B, CARRY is A and B. Both switches on, and it reads sum zero, carry one, which is how binary writes one plus one equals one zero.

The on-screen lines live in `../strings.js`: `flow.led-basics.<key>` and
`flow.logic-gates.<key>` for the whole-step clips, and the say cues of
`flow.led-basics.<key>.script` for the per-line ones. A changed English line
there wants its clip rendered again and its text here updated; a clip that
cannot be rendered is removed, so the line shows as text only.
