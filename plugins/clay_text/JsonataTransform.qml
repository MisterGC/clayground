// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype JsonataTransform
    \inqmlmodule Clayground.Text
    \brief JSONata query processor for JSON data transformation.

    JsonataTransform provides a way to query and transform JSON data using
    the JSONata query language. It automatically evaluates the query whenever
    the input data or query string changes.

    JSONata is a lightweight query and transformation language for JSON data.
    See https://jsonata.org for the full language specification.

    Example usage:
    \qml
    import Clayground.Text

    JsonataTransform {
        id: stats
        inputObject: {
            "inventory": [
                {"item": "sword", "value": 100},
                {"item": "potion", "value": 20}
            ]
        }
        jsonataString: "$sum(inventory.value)"
    }

    Text {
        text: "Total value: " + stats.jsonOutput  // "Total value: 120"
    }
    \endqml

    \qmlproperty var JsonataTransform::inputObject
    \brief The input JSON object to query.

    Can be any JavaScript object or array that will be queried
    using the jsonataString expression.

    \qmlproperty string JsonataTransform::jsonataString
    \brief The JSONata query expression to evaluate.

    Examples: "$sum(items.price)", "orders[status='pending']",
    "$max(scores.value)".

    \qmlproperty var JsonataTransform::jsonOutput
    \readonly
    \brief The result of evaluating the JSONata query.

    This property updates automatically when inputObject or
    jsonataString changes.
*/

import QtQuick
import Clayground.Text
import "qrc:/Clayground/Text/jsonata.js" as Jsonata

Item {
    property var inputObject: {example: [{value: 4}, {value: 7}, {value: 13}]}
    property string jsonataString: "$max(example.value)"
    readonly property var jsonOutput: Jsonata.jsonata(jsonataString).evaluate(inputObject)
}
