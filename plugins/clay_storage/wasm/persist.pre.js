// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Linked into every WebAssembly app that links Clayground.Storage
// (--pre-js, see CMakeLists.txt). Without it, a KeyValueStore lives in
// Emscripten's in-memory file system and is gone after a page reload (#341).
//
// The XDG data directory - where QML LocalStorage keeps its databases
// (<data>/<app>/QML/OfflineStorage) and where QStandardPaths puts app data -
// is mounted as IDBFS and filled from IndexedDB before main() runs, so the
// first KeyValueStore already finds what an earlier visit stored.
// Module.clayStoragePersist() writes it back; StorageSync.persist() calls it.
//
// Storage is never a reason not to start: without IndexedDB (some private
// windows, blocked site data) the directory stays in memory as before and
// the app boots, with one warning in the console.

if (typeof ENVIRONMENT_IS_PTHREAD === 'undefined' || !ENVIRONMENT_IS_PTHREAD) {
    Module['preRun'] = [].concat(Module['preRun'] || []);
    Module['preRun'].push(() => {
        const env = typeof ENV === 'object' ? ENV : {};
        const dir = env['XDG_DATA_HOME']
            || (env['HOME'] || '/home/web_user') + '/.local/share';
        let usable = true;
        let running = false;
        let again = false;

        const warn = (what, err) => {
            usable = false;
            console.warn('Clayground.Storage: ' + what + ' - stored data lasts only '
                         + 'until the page reloads (' + err + ')');
        };

        // IDBFS asserts on a missing IndexedDB, and the assertion aborts the
        // whole runtime - ask first.
        if (typeof indexedDB === 'undefined' || !indexedDB) {
            warn('no IndexedDB in this browser context', 'indexedDB is undefined');
            return;
        }
        try {
            FS.mkdirTree(dir);
            FS.mount(IDBFS, {}, dir);
        } catch (e) {
            warn('cannot mount IndexedDB storage at ' + dir, e);
            return;
        }

        Module['clayStoragePersist'] = () => {
            if (!usable)
                return;
            if (running) {
                again = true;
                return;
            }
            running = true;
            const done = err => {
                running = false;
                if (err)
                    warn('cannot write to IndexedDB', err);
                else if (again) {
                    again = false;
                    Module['clayStoragePersist']();
                }
            };
            // An IDBFS that cannot open its database may throw instead of
            // calling back.
            try { FS.syncfs(false, done); } catch (e) { done(e); }
        };

        addRunDependency('clay-storage');
        const loaded = err => {
            if (err)
                warn('cannot read from IndexedDB', err);
            removeRunDependency('clay-storage');
        };
        try { FS.syncfs(true, loaded); } catch (e) { loaded(e); }
    });
}
