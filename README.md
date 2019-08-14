## Flow, form, create 
Clayground is a Qt based environment that allows using QML to rapidly
develop apps in a sandbox environment with live loading. It tries to 
provide tools that allows both to learn and develop more focused and
faster by reducing build times significantly and avoiding the need 
to restart apps. 

### Available Plugins
Clayground comes with a set of plugins that extend Qt capabilities in order to build interactive experiences:
- Physics/Box2D: Adds 2d Phyiscs capabilities
- Scaling Canvas: A canvas component that provides a 2d virtual/world coordinate
  system tries to hide dealing with pixels as much as possible.
- SVG Utils: Allows inspection of (Inkscape based) SVGs, can be easily used to 
- GameController: Supports game input using three different sources GamePad, Keyboard and Touch Screen with single component.

### Available Examples
A bunch of example application allow you to try it out easily: 
- GUI: Very basic app which helps to learn QtQuick.Controls. 
- Particle: Suitable to experiment with/learn the Qt Particle system.
- Platformer: Starting point for a platformer game. 
- TopDown: Starting point for a topdown game (for example a classical RPG).

### How to work with a sandbox?
1. Clone this repo and build it (Qt 5.13.x, Qt Creator)
2. Start the qml_live_loader app `qml_live_loader --dynqmldir=<clone-dir>/sandboxes/gui`
3. Move the window (which always stays on top) to a location that allows you to easily changes without
covering important parts of your code editor.
4. Make changes to `<clone-dir>/sandboxes/gui/Sandbox.qml` -> see the changes live applied
5. Check out the other sandboxes in the same way :)
