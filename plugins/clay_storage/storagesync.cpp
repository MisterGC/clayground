// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "storagesync.h"

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

/*!
    \qmltype StorageSync
    \nativetype StorageSync
    \inqmlmodule Clayground.Storage
    \brief Makes what was stored survive a browser reload.

    In a WebAssembly build, files live in memory and are gone when the page
    reloads. Clayground.Storage therefore keeps the data directory (where
    QML LocalStorage puts its databases) in the browser's IndexedDB: it is
    loaded from there before the app starts, and persist() writes it back.

    KeyValueStore calls persist() after every change, so a KeyValueStore
    needs nothing more. Call it yourself only after writing to that
    directory some other way, e.g. with QtQuick.LocalStorage directly:

    \qml
    import QtQuick.LocalStorage
    import Clayground.Storage

    function save(db, score) {
        db.transaction(tx => tx.executeSql('INSERT INTO scores VALUES (?)', [score]))
        StorageSync.persist()
    }
    \endqml

    In a native build there is nothing to write back and persist() does
    nothing.
*/

StorageSync::StorageSync(QObject* parent)
    : QObject(parent)
{
}

/*!
    \qmlmethod void StorageSync::persist()

    Writes the data directory back to IndexedDB, in the background. Calls
    that arrive while a write is still running are folded into one more
    write after it.
*/
void StorageSync::persist()
{
#ifdef __EMSCRIPTEN__
    // The file system and IndexedDB belong to the browser's main thread; the
    // write runs there and finishes asynchronously anyway.
    MAIN_THREAD_ASYNC_EM_ASM({
        if (Module['clayStoragePersist'])
            Module['clayStoragePersist']();
    });
#endif
}
