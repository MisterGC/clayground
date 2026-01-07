// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype KeyValueStore
    \inqmlmodule Clayground.Storage
    \brief A persistent key-value storage component using SQLite database.

    KeyValueStore provides a simple interface for storing and retrieving
    key-value pairs that persist across application sessions. It uses
    Qt's LocalStorage module backed by SQLite.

    Example usage:
    \qml
    import Clayground.Storage

    KeyValueStore {
        id: settings
        name: "MyGameSettings"
    }

    Component.onCompleted: {
        settings.set("highScore", "1000")
        let score = settings.get("highScore", "0")
        console.log("High score:", score)
    }
    \endqml

    \qmlproperty string KeyValueStore::name
    \brief The database name used for storage.

    Must be set before using the store. Each unique name creates a separate
    SQLite database file. Use descriptive names to avoid conflicts between
    different storage purposes (e.g., "GameSettings", "PlayerProgress").
*/

import QtQuick.LocalStorage
import QtQuick

Item
{
    property string name: ""
    readonly property var _db: LocalStorage.openDatabaseSync(name, "0.1", "A simple key-value store", 10000);
    on_DbChanged: _db.transaction((tx) => {
            tx.executeSql('CREATE TABLE IF NOT EXISTS keyvalue(key TEXT UNIQUE, value TEXT)');
        });

    /*!
        \qmlmethod bool KeyValueStore::set(string key, string value)
        \brief Stores a key-value pair in the database.

        Inserts a new key-value pair or replaces an existing one.

        \a key The unique identifier for the value.
        \a value The string value to store.

        Returns true if the operation succeeded, false otherwise.
    */
    function set(key, value) {
        var res = true;
        _db.transaction((tx) => {
            let rs = tx.executeSql('INSERT OR REPLACE INTO keyvalue VALUES (?,?);', [key,value]);
            res = rs.rowsAffected === 1 ? true : false;
        });
        return res;
    }

    /*!
        \qmlmethod string KeyValueStore::get(string key, string defVal)
        \brief Retrieves the value for a given key.

        \a key The unique identifier to look up.
        \a defVal The default value to return if the key is not found.

        Returns the stored value, or defVal if the key does not exist.
    */
    function get(key, defVal) {
        var res = true;
        _db.transaction((tx) => {
            let rs = tx.executeSql('SELECT value FROM keyvalue WHERE key=?;', [key]);
            res = rs.rows.length === 1 ? rs.rows.item(0).value : defVal;
        });
        return res;
    }

    /*!
        \qmlmethod bool KeyValueStore::has(string key)
        \brief Checks if a key exists in the database.

        \a key The unique identifier to check.

        Returns true if the key exists, false otherwise.
    */
    function has(key) {
        let res = false;
        _db.transaction((tx) => {
            let rs = tx.executeSql('SELECT value FROM keyvalue WHERE key=?;', [key]);
            res = rs.rows.length > 0;
        });
        return res;
    }

    /*!
        \qmlmethod bool KeyValueStore::remove(string key)
        \brief Removes a key-value pair from the database.

        \a key The unique identifier to remove.

        Returns true after the operation completes.
    */
    function remove(key) {
        _db.transaction((tx) => {
            let rs = tx.executeSql('DELETE FROM keyvalue WHERE key=?;', [key]);
        });
        return true;
    }
}
