// (c) Clayground Contributors - MIT License, see "LICENSE" file
// probe for #386: a PR that touches only a test (not for merge)
//
// KeyValueStore on a native build: what it stores is read back - also by
// another store of the same name, i.e. from the database file and not from
// the object that wrote it - and StorageSync.persist(), which every change
// calls to keep a web build's data across a reload (#341), changes nothing.

import QtQuick
import QtTest
import Clayground.Storage

Item {
    id: root

    readonly property string storeName: "clay-storage-suite"

    KeyValueStore { id: store; name: root.storeName }

    Component { id: storeFactory; KeyValueStore { } }

    TestCase {
        name: "KeyValueStore"

        function cleanup() {
            store.remove("a")
            store.remove("b")
        }

        function test_set_get_has_remove() {
            compare(store.has("a"), false)
            compare(store.get("a", "fallback"), "fallback")
            verify(store.set("a", "1"))
            compare(store.has("a"), true)
            compare(store.get("a", "fallback"), "1")
            verify(store.set("a", "2"))
            compare(store.get("a", ""), "2")
            verify(store.remove("a"))
            compare(store.has("a"), false)
        }

        function test_another_store_of_the_same_name_reads_it() {
            verify(store.set("b", "kept"))
            const other = createTemporaryObject(storeFactory, root, {name: root.storeName})
            verify(other)
            compare(other.get("b", ""), "kept")
        }

        function test_persist_is_harmless_natively() {
            verify(store.set("a", "x"))
            StorageSync.persist()
            StorageSync.persist()
            compare(store.get("a", ""), "x")
        }
    }
}
