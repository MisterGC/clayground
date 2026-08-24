// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma Singleton
import QtQuick
import "format.js" as Format

/*!
    \qmltype LabLang
    \inqmlmodule Clayground.Lab
    \brief Runtime language switch for labs: dictionaries, lookup and number format.

    A lab that is meant to be published to a classroom needs its wording in
    the reader's language, switchable while it runs. Qt's own \c qsTr route
    cannot do that here: retranslating a live QML engine is a C++ call on the
    engine, and a lab hosted by the dojo (or exported to WASM) never owns that
    engine. So translation is a runtime dictionary instead, and every string
    is an ordinary binding that re-evaluates when \l lang changes.

    Dictionaries are registered by whoever owns the vocabulary - a kit
    registers its part names, the lab registers its own UI copy:

    \qml
    import Clayground.Lab
    import "strings.js" as Strings

    Component.onCompleted: LabLang.register(Strings.dict)
    Text { text: LabLang.t("hint.wire") }
    Text { text: LabLang.num(4.32, 2) + " V" }   // "4,32 V" in German
    \endqml

    \sa Lab, LangSwitch
*/
QtObject {
    id: _lang

    /*!
        \qmlproperty string LabLang::lang
        \brief Active language code, e.g. "en" or "de".
    */
    property string lang: "en"

    /*!
        \qmlproperty var LabLang::languages
        \brief Language codes offered by the registered dictionaries.
    */
    property var languages: ["en"]

    /*!
        \qmlproperty string LabLang::decimalPoint
        \brief Decimal separator of the active language.
    */
    readonly property string decimalPoint: lang === "en" ? "." : ","

    // lang -> {key: text}; reassigned (never mutated) so bindings re-evaluate
    property var _dicts: ({})

    /*!
        \qmlmethod void LabLang::register(var dict)
        \brief Merges \c {{lang: {key: text}}} into the registry.

        Later registrations win on conflicting keys, so a lab may override a
        kit's wording. Registering also extends \l languages.
    */
    function register(dict) {
        const merged = {}
        for (const l in _dicts) merged[l] = _dicts[l]
        for (const l in dict) {
            const target = {}
            for (const k in merged[l]) target[k] = merged[l][k]
            for (const k in dict[l]) target[k] = dict[l][k]
            merged[l] = target
        }
        _dicts = merged
        // English first (the fallback language), the rest alphabetically
        const langs = []
        for (const l in merged) if (l !== "en") langs.push(l)
        langs.sort()
        languages = (merged["en"] ? ["en"] : []).concat(langs)
    }

    /*!
        \qmlmethod string LabLang::t(string key)
        \brief The key's text in the active language.

        Falls back to English and then to the key itself, so a missing
        translation shows up as the key rather than as an empty label.
    */
    function t(key) {
        const d = _dicts[lang]
        if (d && d[key] !== undefined) return d[key]
        const en = _dicts["en"]
        if (en && en[key] !== undefined) return en[key]
        // kernel chrome last: a lab that registers its own wording always wins,
        // whatever order the dictionaries happened to be registered in
        const kd = _kernel[lang]
        if (kd && kd[key] !== undefined) return kd[key]
        const ken = _kernel["en"]
        if (ken && ken[key] !== undefined) return ken[key]
        return key
    }

    /*!
        \qmlmethod string LabLang::tf(string key, ...)
        \brief \l t() with \c %1, \c %2 ... replaced by the extra arguments.
    */
    function tf(key) {
        let out = t(key)
        for (let i = 1; i < arguments.length; ++i)
            out = out.replace("%" + i, arguments[i])
        return out
    }

    /*!
        \qmlmethod string LabLang::num(real v, int digits)
        \brief Formats a number in the active language's decimal notation.

        \c digits is optional; without it the value is printed as-is. German
        (and any language whose separator is not ".") gets a decimal comma, so
        readouts match what a student writes in their exercise book.
    */
    function num(v, digits) {
        const s = digits === undefined ? String(v) : Number(v).toFixed(digits)
        return decimalPoint === "." ? s : s.replace(".", decimalPoint)
    }

    /*!
        \qmlmethod string LabLang::qty(real v, string unit, int digits)
        \brief A quantity with its SI prefix chosen for readability.

        \c {qty(0.05, "A")} is \c {"50.0 mA"}, \c {qty(1500, "Ω")} is
        \c {"1.50 kΩ"}, and both follow the language's decimal separator.
        Every lab so far hand-rolled its own mA/A crossover, differently and
        once per unit; this is that rule, in one place, with a node suite
        behind it.

        \a digits is optional - without it the value gets three significant
        figures, which is what an instrument reading is worth. Units that
        cannot take a prefix (\c "%", \c "/min", a bare count) are printed
        as they stand.

        \sa num()
    */
    function qty(v, unit, digits) {
        return Format.qty(v, unit, digits, decimalPoint)
    }

    /*!
        \qmlmethod var LabLang::qtyParts(real v, string unit, int digits)
        \brief \l qty() split into \c {{number, prefix, unit, fullUnit}}.

        For a readout that sets the number and the unit in different type - a
        gauge, a big status figure - so it never has to re-split a formatted
        string to get there.
    */
    function qtyParts(v, unit, digits) {
        return Format.parts(v, unit, digits, decimalPoint)
    }

    /*!
        \qmlmethod string LabLang::langName(string code)
        \brief Display name for a language code (the code itself if unknown).
    */
    function langName(code) {
        const names = { "en": "EN", "de": "DE" }
        return names[code] ? names[code] : code.toUpperCase()
    }

    onLangChanged: LabPrefs.set("ui.lang", lang)

    // The language a lab is read in belongs to the reader, not to the run.
    // Applied only once a dictionary actually offers it, so an early restore
    // cannot strand the lab in a language nothing is registered for.
    property string _wanted: ""
    function _applyWanted() {
        if (_wanted !== "" && languages.indexOf(_wanted) !== -1 && lang !== _wanted)
            lang = _wanted
    }
    onLanguagesChanged: _applyWanted()
    Component.onCompleted: {
        _wanted = String(LabPrefs.get("ui.lang", ""))
        _applyWanted()
    }

    // The kernel's own strings, so a lab gets its chrome translated without
    // registering anything itself. Everything a KERNEL widget renders belongs
    // here - the flow chrome lived in two labs' dictionaries word for word
    // before this, and the third lab would have copied it again.
    //
    // Deliberately NOT register()ed: registration is last-wins, and the
    // singleton is created whenever it is first touched, so a kernel
    // registration could land after a lab's and silently overwrite its
    // wording. As a fallback layer inside t() the lab always wins, whatever
    // the creation order turns out to be.
    readonly property var _kernel: ({
        "en": {
            "lab.parameters": "PARAMETERS",
            "flow.paused": "paused — you took over",
            "flow.next": "next ›",
            "flow.back": "‹ back",
            "flow.resume": "resume",
            "flow.leave": "✕ leave",
            "flow.showme": "show me",
            "flow.watching": "watching…",
            "flow.start": "start the tour",
            "keys.title": "KEYS",
            "keys.hint": "? keys",
            "keys.scenarios": "presets",
            "keys.flow": "guided tour",
            "keys.next": "next step",
            "keys.back": "step back",
            "keys.frame": "frame selection",
            "keys.reset": "reset view",
            "keys.record": "record a run",
            "keys.cancel": "cancel",
            "keys.focus": "hide the panels",
            "keys.help": "this list",
            "keys.view": "turn · zoom the view",
            "keys.pan": "move across the scene",
            "keys.orbit": "turn the view",
            "keys.zoom": "zoom",
            "keys.uiscale": "text size",
            "keys.nav": "pan on the left button while held",
            "keys.hand": "take the next instrument",
            "keys.pin": "keep this reading",
            "keys.unmeasure": "undo the last point · Esc clears",
            "mode.hint.hand": "click measures · right-drag turns the view · ⌫ undoes · P keeps it · Esc clears",
            "hand.hint.clock": "click starts the clock · click again stops it · sim seconds, so pausing pauses it",
            "hand.tape": "tape",
            "hand.stopwatch": "clock",
            "hand.volts": "volts",
            "hand.pin.ask": "keep this reading as",
            "hand.pin.hint": "⏎ keeps it · Esc cancels",
            "scenario.pick": "presets",
            "watch.add": "watch",
            "watch.on": "watching",
            "watch.full": "plot full",
            "time.pause": "pause",
            "time.resume": "resume",
            "rec.label": "REC",
            "dock.hidden": "put away",
            "dock.showAll": "all back"
        },
        "de": {
            "lab.parameters": "PARAMETER",
            "flow.paused": "angehalten — du übernimmst",
            "flow.next": "weiter ›",
            "flow.back": "‹ zurück",
            "flow.resume": "fortsetzen",
            "flow.leave": "✕ beenden",
            "flow.showme": "zeig es mir",
            "flow.watching": "beobachten…",
            "flow.start": "Tour starten",
            "keys.title": "TASTEN",
            "keys.hint": "? Tasten",
            "keys.scenarios": "Vorlagen",
            "keys.flow": "geführte Tour",
            "keys.next": "nächster Schritt",
            "keys.back": "Schritt zurück",
            "keys.frame": "Auswahl zeigen",
            "keys.reset": "Ansicht zurücksetzen",
            "keys.record": "Lauf aufzeichnen",
            "keys.cancel": "abbrechen",
            "keys.focus": "Bedienfelder aus",
            "keys.help": "diese Liste",
            "keys.view": "Ansicht drehen · zoomen",
            "keys.pan": "Szene durchqueren",
            "keys.orbit": "Ansicht drehen",
            "keys.zoom": "zoomen",
            "keys.uiscale": "Schriftgröße",
            "keys.nav": "halten: linke Taste bewegt die Ansicht",
            "keys.hand": "nächstes Instrument nehmen",
            "keys.pin": "Messwert behalten",
            "keys.unmeasure": "letzten Punkt zurück · Esc löscht",
            "mode.hint.hand": "Klick misst · rechte Taste dreht die Ansicht · ⌫ zurück · P behält · Esc löscht",
            "hand.hint.clock": "Klick startet die Uhr · nochmal Klick stoppt sie · Simulationssekunden, Pause hält sie an",
            "hand.tape": "Maßband",
            "hand.stopwatch": "Uhr",
            "hand.volts": "Volt",
            "hand.pin.ask": "Messwert behalten als",
            "hand.pin.hint": "⏎ behält · Esc bricht ab",
            "scenario.pick": "Vorlagen",
            "watch.add": "beobachten",
            "watch.on": "beobachtet",
            "watch.full": "Plot voll",
            "time.pause": "Pause",
            "time.resume": "weiter",
            "rec.label": "AUFN",
            "dock.hidden": "weggelegt",
            "dock.showAll": "alle zurück"
        }
    })
}
