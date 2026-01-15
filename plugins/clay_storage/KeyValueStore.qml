// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick.LocalStorage
import QtQuick

Item
{
    property string name: ""
    readonly property var _db: LocalStorage.openDatabaseSync(name, "0.1", "A simple key-value store", 10000);
    on_DbChanged: _db.transaction((tx) => {
            tx.executeSql('CREATE TABLE IF NOT EXISTS keyvalue(key TEXT UNIQUE, value TEXT)');
        });

    function set(key, value) {
        var res = true;
        _db.transaction((tx) => {
            let rs = tx.executeSql('INSERT OR REPLACE INTO keyvalue VALUES (?,?);', [key,value]);
            res = rs.rowsAffected === 1 ? true : false;
        });
        return res;
    }

    function get(key, defVal) {
        var res = true;
        _db.transaction((tx) => {
            let rs = tx.executeSql('SELECT value FROM keyvalue WHERE key=?;', [key]);
            res = rs.rows.length === 1 ? rs.rows.item(0).value : defVal;
        });
        return res;
    }

    function has(key) {
        let res = false;
        _db.transaction((tx) => {
            let rs = tx.executeSql('SELECT value FROM keyvalue WHERE key=?;', [key]);
            res = rs.rows.length > 0;
        });
        return res;
    }

    function remove(key) {
        _db.transaction((tx) => {
            let rs = tx.executeSql('DELETE FROM keyvalue WHERE key=?;', [key]);
        });
        return true;
    }
}
