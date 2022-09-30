// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick 2.0
import Clayground.Text
import "qrc:/Clayground/Text/jsonata.js" as Jsonata

Item {
    property var inputObject: {example: [{value: 4}, {value: 7}, {value: 13}]}
    property string jsonataString: "$max(example.value)"
    readonly property var jsonOutput: Jsonata.jsonata(jsonataString).evaluate(inputObject)
}
