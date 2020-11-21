// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick.LocalStorage 2.12
import QtQuick 2.12


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
}
