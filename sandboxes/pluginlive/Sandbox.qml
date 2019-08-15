import QtQuick 2.12
import QtQuick.Controls 2.5
import MyPlugin 1.0

Rectangle
{
    color: "orange"
    MyComponent
    {
        Component.onCompleted: console.log(sayHello());
    }
}
