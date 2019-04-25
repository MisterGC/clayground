import QtQuick 2.12
import QtQuick.Controls 2.5
import "qrc:/" as LivLd
import GcPopulator 1.0

Rectangle
{
    color: "grey"
    Populator
    {
        Component.onCompleted: loadSvgPopulationModel("/home/mistergc/dev/qml_live_loader/sandboxes/populator/sample_level.svg")
        onCreateItemAt: {
            console.log("Create item: " + componentName + " x: " + x + " y: " + y);
        }
    }

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
