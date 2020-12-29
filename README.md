![clayground](res/clayground_logo.png)



## Flow, form, create 
When participating at [Ludum Dare 44](https://ldjam.com) I started to develop
utilities and a LiveLoading app to ease game creation. As I really enjoyed
using these components, I decided to create separate project and make it
open source.

Clayground is a [Qt](https://www.qt.io) based toolset that allows using C++, JavaScript
and [QML](https://doc.qt.io/qt-5/qtqml-index.html) to rapidly develop apps in a sandbox environment with live loading capabilities.
It provides tools that try both facilitating learning and allowing more
focused and faster development by reducing typical build and restart times
significantly.

![Platformer Screenshot](res/screenshot_platformer.png)

Goals/Basic Design Decisions:
- Use Qt (Quick): Don't write everything from scratch, but think how to re-combine Qt's capabilities 
- Code > Graphical Tools: Focus on minimizing time needed to write and debug applications
- Don't write graphical tools, but support formats which can be used with popular free tools 
- Add dedicated APIs but still allow bypassing them (full power of Qt/Qml, C++, JavaScript)
- Target (rapid) prototyping and small/medium app development

### Available Plugins
Clayground comes with a set of plugins that extend Qt capabilities in order to
build interactive experiences:
- Physics/Box2D: Adds 2D Physics capabilities
- Canvas: A canvas component that provides a 2D virtual/world coordinate
  system tries to hide dealing with pixels as much as possible.
- SVG Utils: Allows inspection of (Inkscape based) SVGs, can be used to create 2d scenes
- GameController: Supports game input using three different sources GamePad, Keyboard and Touch Screen with single component.
- Storage: Get persistent storage with a very simple API
- World: Uses Canvas, Physics and SVG to provide a foundation for small games and simulations

### Available Examples
A bunch of example application allow you to try it out easily:
- GUI: Visual training app for keyboard shortcuts, comes with a configuration for Inkscape.
- VisualFX: Implementation of different visual effects, includes usage of the [Qt Particle System](https://doc.qt.io/qt-5/qtquick-effects-particles.html).
- Platformer: Starting point for a platformer game.
- TopDown: Starting point for a topdown game (for example a classical RPG).
- PluginLive: Demonstrates how to use the Clayground LiveLoader to develop a C++ plugin.

### How to work with a sandbox?
1. Clone this repo and build it (Qt 5.15.x, Qt Creator)
2. Start the qml_live_loader app `clayrestarter --dynimportdir=<clone-dir>/sandboxes/void`
3. Move the window to a location that allows you to keep it visible even when your are editing code.
4. Make changes to `<clone-dir>/sandboxes/void/Sandbox.qml` -> see the changes live applied
5. Check out the other sandboxes in the same way :)

#### Using the Logging Overlay
The sandbox comes with a logging overlay that shows all 
`console.log(...)` messages in a continous log view and 
watched properties/expressions in a sticky section. You can 
easily show/hide the overlay by using the `log` button of the 
restarter or by pressing lower-case L when the Sbx Window has the focus.

<img src="res/log_overlay.png" width="50%" height="50%" alt="LogOverlay Screenshot">

Have a look at the `onMapLoaded` signal handler of the Platformer 
Sandbox to see how you can use them.

### How to create a deployable app?
Each of the demo sandboxes also comes with a CMake application configuration which 
allows to build a standalone app. So you can just use one as a template to build your own app.

### Is there any recommended development setup?
- OS: Linux (fastest and easy to use) - I have also used it on macOS and Windows 10, still good but use Linux if you can 
- IDE/Editor: Qt Creator as it also allows you to easily debug and profile resulting apps - additionally I use Vim for various text processing tasks


I hope you enjoy using clayground, feel free to create issues or to contribute :)
