import QtQuick 2.12
import QtQuick.Controls 2.5
import "qrc:/" as LivLd

Rectangle
{
    color: "grey"
    Column
    {
        spacing: 10
        ComboBox {
            width: 200
            model: ["One", "Two", "Three"]
        }
        ComboBox {
            width: 200
            model: ["Another", "Hmm", "Three"]
        }
        RoundButton {
            text: "What's this?"
            width: 300
        }
        CheckBox { checked: true; text: "With Sugar" }
        CheckBox { checked: true; text: "With Milk" }
    }

}
