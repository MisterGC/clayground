// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Linked into every WebAssembly app that links Clayground.Sound (--pre-js,
// see CMakeLists.txt).
//
// A browser starts an AudioContext only once the page has had a user
// gesture; one created before that stays suspended until resume() is called
// after one. Emscripten's OpenAL - what Qt's audio sink plays through -
// calls resume() from mousedown, keydown and touchstart listeners on the
// document. A click on a Qt window never gets there: Qt takes the
// pointerdown, prevents its default, so the browser sends no mousedown, and
// stops it. A page whose sound started before the first click - a title
// tune, a note at load - stayed silent for good (#480, measured on Chrome
// 153 and 156).
//
// So every AudioContext the browser holds back is resumed on the next
// gesture the window sees, in the capture phase, before Qt's handlers. A
// context that has left the suspended state once is not touched again: a
// suspend() after that is the app's own.

if (typeof AudioContext !== 'undefined') {
    const heldBack = new Set();
    globalThis.AudioContext = new Proxy(AudioContext, {
        construct(target, args, newTarget) {
            const ctx = Reflect.construct(target, args, newTarget);
            if (ctx.state === 'suspended') {
                heldBack.add(ctx);
                ctx.addEventListener('statechange', () => {
                    if (ctx.state !== 'suspended')
                        heldBack.delete(ctx);
                });
            }
            return ctx;
        }
    });
    const resumeHeldBack = () => {
        for (const ctx of heldBack)
            ctx.resume().catch(() => {});
    };
    for (const type of ['pointerdown', 'pointerup', 'click', 'keydown', 'touchend'])
        globalThis.addEventListener(type, resumeHeldBack, true);
}
