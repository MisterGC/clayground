// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the performance script parser.
//
//     node plugins/clay_character3d/scripting/performancescript.test.js
//
// The parser is Qt-free (`.pragma library`, no Qt types, no clock) precisely
// so it can be checked here, in a second, without a running engine. The
// harness strips the pragma and evaluates the module into a scope.
//
// An authoring format is a contract: every script written against it has to
// keep parsing the same way, so this suite is a parser suite rather than a
// smoke test. It pins each directive form, the exact boundary of the time-hint
// rule (the one place where prose and syntax touch), what strict mode refuses,
// and what the cross-language lint catches.
const K = require('../../../labs/kits/kitcheck.js')

const P = K.load(__dirname, 'performancescript.js', ['parse', 'lint', 'describe'])

const ok = K.ok, eq = K.eq, section = K.section

// Shorthands: the cue list, and the cue list as describe() lines.
const cues = (s, o) => P.parse(s, o).cues
const errs = (s, o) => P.parse(s, o).errors
const shape = (s, o) => cues(s, o).map(P.describe).join(' | ')

// ---------------------------------------------------------------- directives
section('directives: emotion')
{
    eq('happy', shape('*happy*'), 'emotion happy')
    eq('sad', shape('*sad*'), 'emotion sad')
    eq('angry', shape('*angry*'), 'emotion angry')
    eq('neutral', shape('*neutral*'), 'emotion neutral')
    eq('alias joy', cues('*joy*')[0].value, 'happy')
    eq('alias sadness', cues('*sadness*')[0].value, 'sad')
    eq('alias anger', cues('*anger*')[0].value, 'angry')
    eq('alias calm is the neutral face', cues('*calm*')[0].value, '')
    eq('emotion is a cue, not text', cues('*happy*').length, 1)
}

section('directives: targets')
{
    const c = cues('*point at battery*')[0]
    eq('point type', c.type, 'point')
    eq('point target', c.target, 'battery')

    eq('multi-word target keeps its spaces',
       cues('*point at the big red battery*')[0].target, 'the big red battery')
    eq('inner whitespace is normalized',
       cues('*point   at    the  battery*')[0].target, 'the battery')
    eq('a target is an objectName, so its case survives',
       cues('*point at BatteryTerminal*')[0].target, 'BatteryTerminal')

    eq('look at a name', shape('*look at battery*'), 'look at battery')
    eq('look at the viewer', shape('*look at viewer*'), 'look at viewer')
    eq('viewer is case-insensitive', cues('*look at Viewer*')[0].target, 'viewer')
    eq('face the viewer', shape('*face viewer*'), 'face viewer')
    eq('face a name', cues('*face the board*')[0].target, 'the board')
    eq('face is a whole-body turn, look is not',
       cues('*face viewer*')[0].type + '/' + cues('*look at viewer*')[0].type,
       'face/look')
}

section('directives: gestures')
{
    eq('thumbs up', shape('*thumbs up*'), 'thumbs up')
    eq('gesticulate', shape('*gesticulate*'), 'gesticulate')
    eq('rest', shape('*rest*'), 'rest')
}

section('directives: case and layout')
{
    eq('upper case', shape('*HAPPY*'), 'emotion happy')
    eq('mixed case verb', shape('*Point At battery*'), 'point at battery')
    eq('padded', shape('*  thumbs   up  *'), 'thumbs up')
    eq('a newline is just whitespace',
       shape('*happy*\n\nHello.\n*rest*'), "emotion happy | say 'Hello.' | rest")
}

section('directives: pause')
{
    eq('milliseconds', cues('*pause 800ms*')[0].ms, 800)
    eq('seconds', cues('*pause 2s*')[0].ms, 2000)
    eq('fractional seconds', cues('*pause 1.5s*')[0].ms, 1500)
    eq('a space before the unit is allowed', cues('*pause 800 ms*')[0].ms, 800)
    eq('describe prints ms', P.describe(cues('*pause 2s*')[0]), 'pause 2000ms')

    eq('a bare number is not a duration', cues('*pause 800*').length, 0)
    eq('and it is reported', errs('*pause 800*').length, 1)
    ok('the message names the duration',
       errs('*pause 800*')[0].message.indexOf('800') >= 0)
    eq('an unknown unit is refused', errs('*pause 2 seconds*').length, 1)
    eq('a missing duration is refused', errs('*pause*').length, 1)
    eq('a duration is never spoken', cues('*pause 2 seconds*').length, 0)
}

// ---------------------------------------------------------------- speech runs
section('speech runs')
{
    eq('plain text is one say cue', cues('Hello there.').length, 1)
    eq('text is trimmed', cues('   Hello there.   ')[0].text, 'Hello there.')
    eq('a run is not split into sentences',
       cues('One. Two. Three.').length, 1)
    eq('directives cut runs apart',
       shape('Left. *rest* Right.'), "say 'Left.' | rest | say 'Right.'")
    eq('whitespace between two directives is not a run',
       cues('*happy*   *rest*').length, 2)
    eq('a say cue points at its first character',
       cues('*happy* Hello.')[0 + 1].at, 8)
    eq('a directive points at its opening asterisk',
       cues('Hello. *happy*')[1].at, 7)
}

section('speech runs: the time hint')
{
    const c = cues('This is the battery. (2s)')[0]
    eq('the hint leaves the text', c.text, 'This is the battery.')
    eq('the hint is milliseconds', c.hintMs, 2000)
    eq('no hint is null', cues('This is the battery.')[0].hintMs, null)
    eq('milliseconds', cues('Short. (800ms)')[0].hintMs, 800)
    eq('decimals', cues('Short. (1.5s)')[0].hintMs, 1500)
    eq('a space inside the parens is allowed', cues('Short. (800 ms)')[0].hintMs, 800)

    eq('a hint mid-run stays text',
       cues('This (2s) is the battery.')[0].text, 'This (2s) is the battery.')
    eq('and it is not a hint', cues('This (2s) is the battery.')[0].hintMs, null)
    eq('a hint glued to the last word stays text',
       cues('Battery(2s)')[0].text, 'Battery(2s)')
    eq('and it is not a hint either', cues('Battery(2s)')[0].hintMs, null)
    eq('a parenthetical that is not a duration stays text',
       cues('The battery (the big one)')[0].text, 'The battery (the big one)')
    eq('the hint belongs to its own run',
       cues('One. (1s) *rest* Two.')[0].hintMs, 1000)
    eq('and the next run has none', cues('One. (1s) *rest* Two.')[2].hintMs, null)
    eq('describe shows the hint',
       P.describe(cues('Short. (800ms)')[0]), "say 'Short.' (800ms)")
}

// ------------------------------------------------------------------ strictness
section('strictness: an unknown directive')
{
    const r = P.parse('*point at battery* *pointy* Hello.')
    eq('is not a cue', r.cues.length, 2)
    eq('is not spoken', r.cues[1].text, 'Hello.')
    eq('is reported once', r.errors.length, 1)
    eq('with its position', r.errors[0].at, 19)
    eq('and the offending text', r.errors[0].directive, 'pointy')
    ok('and a message naming it', r.errors[0].message.indexOf('pointy') >= 0)

    const lenient = P.parse('*pointy* Hello.', { strict: false })
    eq('lenient mode keeps it as text - what say() does today',
       lenient.cues[0].text, '*pointy* Hello.')
    eq('lenient mode reports nothing', lenient.errors.length, 0)
    eq('lenient mode still understands known directives',
       shape('*happy* Hi.', { strict: false }), "emotion happy | say 'Hi.'")
    eq('strict is the default', P.parse('*pointy*').errors.length, 1)
}

section('strictness: malformed markup')
{
    eq('an unterminated asterisk is an error', errs('*happy* Hello *rest').length, 1)
    eq('and swallows no cue', cues('*happy* Hello *rest').length, 2)
    ok('the error points at the stray asterisk',
       errs('*happy* Hello *rest')[0].at === 14)
    eq('lenient mode speaks it',
       cues('Hello *rest', { strict: false })[0].text, 'Hello *rest')

    eq('an empty directive is an error', errs('*happy* ** Hello.').length, 1)
    ok('and says so', errs('**')[0].message.indexOf('empty') >= 0)
    eq('lenient mode speaks it too',
       cues('** Hello.', { strict: false })[0].text, '** Hello.')
}

// ------------------------------------------------------------------ extraVerbs
section('extraVerbs: the registration seam')
{
    const o = { extraVerbs: ['board out', 'wink'] }
    eq('a registered verb parses', shape('*wink*', o), 'wink')
    eq('as a custom cue', cues('*wink*', o)[0].type, 'custom')
    eq('an argument comes along', cues('*board out to the left*', o)[0].arg,
       'to the left')
    eq('the verb is the registered name', cues('*board out*', o)[0].verb, 'board out')
    eq('no argument is the empty string', cues('*board out*', o)[0].arg, '')
    eq('registration is case-insensitive', cues('*Wink*', o)[0].verb, 'wink')
    eq('unregistered verbs are still errors', errs('*nod*', o).length, 1)
    eq('the built-in vocabulary wins',
       cues('*rest*', { extraVerbs: ['rest'] })[0].type, 'rest')
    eq('a registered verb is not spoken', cues('*wink* Hi.', o).length, 2)
}

// ------------------------------------------------------------------------ lint
section('lint: two languages of one script')
{
    const en = '*point at battery* This is the battery. (2s) *face viewer* *happy* It stores energy.'
    const de = '*point at battery* Das ist die Batterie. *face viewer* *happy* Sie speichert Energie.'
    eq('different words, same direction: in sync', P.lint(en, de).length, 0)

    const reordered = '*face viewer* Das ist die Batterie. *point at battery* *happy* Sie speichert Energie.'
    const r = P.lint(en, reordered)
    ok('a reordered directive is caught', r.length >= 1)
    eq('at the index where they part', r[0].index, 0)
    eq('naming both sides', r[0].a + ' / ' + r[0].b, 'point at battery / face viewer')
    ok('with a mismatch message', r[0].message.indexOf('mismatch') >= 0)

    const dropped = '*point at battery* Das ist die Batterie. *happy* Sie speichert Energie.'
    const d = P.lint(en, dropped)
    eq('a dropped directive is caught', d.length, 2)
    eq('as a missing one at the end', d[1].b, null)
    ok('and says what is missing', d[1].message.indexOf('missing') >= 0)

    const renamed = '*point at Batterie* Das ist die Batterie. *face viewer* *happy* Sie speichert Energie.'
    const a = P.lint(en, renamed)
    eq('a translated target is caught', a.length, 1)
    ok('as an argument difference', a[0].message.indexOf('argument') >= 0)

    const extra = en + ' *thumbs up*'
    const x = P.lint(en, extra)
    eq('an added directive is caught', x.length, 1)
    eq('as an extra one', x[0].a, null)

    eq('a changed pause is a difference',
       P.lint('*pause 2s*', '*pause 3s*').length, 1)
    eq('a changed emotion is a difference',
       P.lint('*happy*', '*sad*').length, 1)
    eq('a changed time hint is not',
       P.lint('*happy* Hello. (1s)', '*happy* Hallo. (3s)').length, 0)
}

// -------------------------------------------------------------------- describe
section('describe')
{
    eq('point', P.describe({ type: 'point', target: 'battery' }), 'point at battery')
    eq('long lines are cut',
       P.describe({ type: 'say', text: 'This is the battery and it stores energy.', hintMs: null }),
       "say 'This is the battery and…'")
    eq('short lines are not',
       P.describe({ type: 'say', text: 'Hello.', hintMs: null }), "say 'Hello.'")
    eq('an unknown cue does not throw', P.describe({ type: 'wat' }), 'wat')
    eq('nothing does not throw either', P.describe(null), '?')
}

// -------------------------------------------------------------- a whole script
section('a whole script')
{
    const script =
        '*point at battery* This is the battery. (2s)\n' +
        '*face viewer* *happy* It stores the energy our circuit spends.\n' +
        '*pause 500ms* *gesticulate* Watch what happens when I close the switch.\n' +
        '*rest* *neutral*'
    const r = P.parse(script)
    eq('parses clean', r.errors.length, 0)
    eq('cue by cue',
       r.cues.map(P.describe).join(' | '),
       "point at battery | say 'This is the battery.' (2000ms) | face viewer | "
       + "emotion happy | say 'It stores the energy our…' | pause 500ms | "
       + "gesticulate | say 'Watch what happens when…' | rest | emotion neutral")
    eq('three lines are spoken',
       r.cues.filter(c => c.type === 'say').length, 3)
    eq('only the first one is timed by hand',
       r.cues.filter(c => c.type === 'say' && c.hintMs !== null).length, 1)
    ok('every cue knows where it came from',
       r.cues.every(c => typeof c.at === 'number' && c.at >= 0))
    ok('and they are in source order',
       r.cues.every((c, i) => i === 0 || c.at >= r.cues[i - 1].at))
    eq('an empty script is nothing at all', P.parse('').cues.length, 0)
    eq('undefined is not a crash', P.parse(undefined).cues.length, 0)
}

process.exit(K.report('performance script'))
