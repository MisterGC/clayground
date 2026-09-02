// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Every user-visible string of {{Title}}, EN and DE, from the first commit.
// The two blocks must carry the SAME KEYS - a missing German key shows the raw
// key on screen, and retrofitting eighty call sites is a whole session.
//
// Rules that hold for every entry here:
//   - no bare literal in Sandbox.qml, ever: LabLang.t(key), LabLang.tf(key,
//     ...args), LabLang.num(v, digits), LabLang.qty(v, unit, digits)
//   - German runs about 25% longer than the English it replaces, so every
//     panel that shows one of these is width-capped and elides
//   - flow narration is keyed flow.<flowId>.<stepKey>, and a hint adds
//     ".hint"; the flow chrome itself (next, back, show me) lives in the
//     kernel dictionary and must never be copied here
//   - a kit would register its vocabulary first and this dictionary second,
//     so this file may override a kit's wording
var dict = {
    "en": {
        "lab.title": "{{Title}}",

        "scenario.intro": "a nudge",
        "scenario.damped": "damped",
        "scenario.note.intro": "pulled 1.6 m aside and let go — it rings for a long time",
        "scenario.note.damped": "the same nudge against four times the damping — two swings and it is over",

        "key.readout": "readings panel",
        "key.plot": "the plot",

        "param.stiffness": "stiffness k",
        "param.damping": "damping c",
        "param.drive": "driving force",

        "quantity.position": "position",
        "quantity.velocity": "velocity",
        "quantity.energy": "energy",

        "readout.title": "RIGHT NOW",
        "readout.caption": "position is measured from rest, not from the wall",

        "plot.empty": "nothing to plot yet",

        "hint.idle": "drag the sliders while it runs · T for the guided tour",
        "hint.damped": "heavily damped: the energy is gone before the second swing",
        "hint.driven": "driven: the force keeps feeding energy in — watch the amplitude settle",

        "banner.runaway": "the mass has left the bench — turn the driving force down or the damping up",

        "flow.{{id}}-intro.title": "how this lab works",
        "flow.{{id}}-intro.intro": "A mass on a spring, pulled aside and released. Nothing else drives it, so every swing is a little smaller than the last: that loss is the damping.",
        "flow.{{id}}-intro.try": "Your turn. Turn the damping up past 1.2 and watch what happens to the ringing.",
        "flow.{{id}}-intro.try.hint": "the damping slider is in the parameters panel on the right",
        "flow.{{id}}-intro.check": "Above about 1.2 the mass barely swings past rest at all — it creeps back instead of ringing. Now try the driving force and see how the two fight."
    },
    "de": {
        "lab.title": "{{Title}}",

        "scenario.intro": "ein Anstoß",
        "scenario.damped": "gedämpft",
        "scenario.note.intro": "1,6 m ausgelenkt und losgelassen — es schwingt lange nach",
        "scenario.note.damped": "derselbe Anstoß gegen die vierfache Dämpfung — nach zwei Schwingungen ist Ruhe",

        "key.readout": "Messwerte-Panel",
        "key.plot": "das Diagramm",

        "param.stiffness": "Steifigkeit k",
        "param.damping": "Dämpfung c",
        "param.drive": "Antriebskraft",

        "quantity.position": "Position",
        "quantity.velocity": "Geschwindigkeit",
        "quantity.energy": "Energie",

        "readout.title": "GERADE JETZT",
        "readout.caption": "die Position wird von der Ruhelage aus gemessen, nicht von der Wand",

        "plot.empty": "noch nichts zu zeigen",

        "hint.idle": "Regler im Lauf verschieben · T startet die Tour",
        "hint.damped": "stark gedämpft: die Energie ist vor der zweiten Schwingung weg",
        "hint.driven": "angetrieben: die Kraft speist ständig Energie nach — sieh der Amplitude beim Einpendeln zu",

        "banner.runaway": "die Masse hat die Bank verlassen — Antriebskraft runter oder Dämpfung rauf",

        "flow.{{id}}-intro.title": "wie dieses Labor funktioniert",
        "flow.{{id}}-intro.intro": "Eine Masse an einer Feder, ausgelenkt und losgelassen. Nichts treibt sie an, also wird jede Schwingung kleiner als die vorige: dieser Verlust ist die Dämpfung.",
        "flow.{{id}}-intro.try": "Jetzt du. Dreh die Dämpfung über 1,2 und sieh dir an, was mit dem Nachschwingen passiert.",
        "flow.{{id}}-intro.try.hint": "der Dämpfungsregler steht im Parameter-Panel rechts",
        "flow.{{id}}-intro.check": "Ab etwa 1,2 schwingt die Masse kaum noch über die Ruhelage hinaus — sie kriecht zurück statt zu schwingen. Probier jetzt die Antriebskraft und sieh, wie beide gegeneinander arbeiten."
    }
}
