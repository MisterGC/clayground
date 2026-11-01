// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Linked into every WebAssembly app that links Clayground.Sound on a Qt
// before 6.11.1 (--pre-js, see CMakeLists.txt).
//
// Qt's web audio device reads the browser's sample rate from a throwaway
// AudioContext: new AudioContext(), resume(), close() - and drops the promise
// resume() returns (QWasmAudioDevice's constructor, once per audio device the
// page sees). Before the page has had a user gesture, Chrome 156 keeps that
// resume() pending, and close() rejects it with "AudioContext closed before a
// pending resume() could complete": an uncaught error in the page for every
// device, before the player has even clicked (#480). Qt 6.11.1 no longer
// calls resume() there (qtmultimedia 90b6668cf6, "wasm: don't try to resume
// AudioContext").
//
// So close() hands every resume() still outstanding on its context a handler,
// before the rejection is due. Only those promises - nothing that resume()
// rejects for any other reason, and nothing a caller handles itself, changes.
// Watching a promise settle would hand it a handler too, so a context's list
// is dropped instead when it starts running: its pending resumes resolve then.

if (typeof AudioContext !== 'undefined' && AudioContext.prototype.resume) {
    const resumes = new WeakMap();
    const resume = AudioContext.prototype.resume;
    const close = AudioContext.prototype.close;
    AudioContext.prototype.resume = function () {
        const pending = resume.apply(this, arguments);
        if (this.state !== 'running' && pending && typeof pending.catch === 'function') {
            if (!resumes.has(this)) {
                resumes.set(this, []);
                this.addEventListener('statechange', () => {
                    if (this.state === 'running')
                        resumes.delete(this);
                });
            }
            resumes.get(this).push(pending);
        }
        return pending;
    };
    AudioContext.prototype.close = function () {
        for (const pending of resumes.get(this) || [])
            pending.catch(() => {});
        resumes.delete(this);
        return close.apply(this, arguments);
    };
}
