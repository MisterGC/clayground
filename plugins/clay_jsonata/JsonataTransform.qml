import QtQuick 2.0
import Clayground.Jsonata
import "qrc:/Clayground/Jsonata/jsonata.js" as Jsonata

Item {
    property var inputObject: {example: [{value: 4}, {value: 7}, {value: 13}]}
    property string jsonataString: "$max(example.value)"
    readonly property var jsonOutput: Jsonata.jsonata(jsonataString).evaluate(inputObject)
}
