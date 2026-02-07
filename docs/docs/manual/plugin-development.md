---
layout: docs
title: Plugin Development
permalink: /docs/manual/plugin-development/
---

Create your own Clayground plugins to extend the framework with custom functionality.

## Plugin Structure

Each plugin follows a consistent structure:

```
plugins/clay_myplugin/
├── CMakeLists.txt
├── MyComponent.qml
├── Sandbox.qml
└── src/
    ├── myclass.cpp
    └── myclass.h
```

## CMake Configuration

Use the `clay_plugin()` macro to define your plugin:

```cmake
clay_plugin(clay_myplugin
    QML_SOURCES
        MyComponent.qml
        Sandbox.qml
    SOURCES
        src/myclass.cpp
        src/myclass.h
)
```

## QML-Only Plugin

For simple plugins without C++ code:

```cmake
clay_plugin(clay_simple
    QML_SOURCES
        SimpleComponent.qml
        Sandbox.qml
)
```

## Importing Your Plugin

In QML files:

```qml
import Clayground.Myplugin

MyComponent {
    // Use your component
}
```

The module name is derived from the plugin directory: `clay_myplugin` becomes `Clayground.Myplugin`.

## C++ Integration

### Registering QML Types

In your plugin's main source file:

```cpp
#include <QtQml/qqmlextensionplugin.h>

class MyPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<MyClass>(uri, 1, 0, "MyClass");
    }
};
```

### Exposing Properties

```cpp
class MyClass : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    QML_ELEMENT

public:
    QString name() const { return m_name; }
    void setName(const QString &name) {
        if (m_name != name) {
            m_name = name;
            emit nameChanged();
        }
    }

signals:
    void nameChanged();

private:
    QString m_name;
};
```

## Testing with Dojo

Every plugin should include a `Sandbox.qml` for testing:

```qml
import QtQuick
import Clayground.Myplugin

Rectangle {
    anchors.fill: parent
    color: "black"

    MyComponent {
        anchors.centerIn: parent
        // Test your component
    }
}
```

Run your plugin's sandbox:

```bash
./build/bin/claydojo --sbx plugins/clay_myplugin/Sandbox.qml
```

## Live Plugin Development

For C++ plugins, use Dojo's dynamic plugin feature:

```bash
./build/bin/claydojo \
    --sbx plugins/clay_myplugin/Sandbox.qml \
    --dynplugin plugins/clay_myplugin,build/plugins/clay_myplugin
```

Rebuild your plugin and Dojo automatically restarts with the updated code.

## Documentation

Document your QML types for the API reference:

```qml
/*!
    \qmltype MyComponent
    \inqmlmodule Clayground.Myplugin
    \brief A component that does something useful.

    Detailed description of the component.

    \sa RelatedType
*/
Item {
    /*!
        \qmlproperty string MyComponent::name
        \brief The name property.
    */
    property string name: ""
}
```

## Best Practices

1. **Follow existing patterns** - Look at built-in plugins for reference
2. **Include a Sandbox.qml** - Makes testing and demonstration easy
3. **Document your types** - Use QDoc comments for API documentation
4. **Keep dependencies minimal** - Only import what you need
5. **Use Common utilities** - `Clayground.Common` provides useful helpers

## Next Steps

- Explore existing [plugins]({{ site.baseurl }}/docs/plugins/)
- Check the [API Reference]({{ site.baseurl }}/api/)
