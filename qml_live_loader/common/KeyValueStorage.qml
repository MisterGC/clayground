/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
import QtQuick 2.12
import QtQuick.LocalStorage 2.12

Item
{
    property string name: ""
    property var _db: LocalStorage.openDatabaseSync(name, "0.1", "A simple key-value store", 10000);

    Component.onCompleted: {
        _db.transaction((tx) => {
            tx.executeSql('CREATE TABLE IF NOT EXISTS keyvalue(key TEXT UNIQUE, value TEXT)');
        });
    }

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
