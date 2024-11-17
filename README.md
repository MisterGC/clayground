# Clayground: Flow, Form, Create

![clayground](res/clayground_logo.png)

## Overview

When participating at [Ludum Dare 44](https://ldjam.com) I started to develop
utilities and a live loading app to ease game creation. As I really enjoyed
using these components, I decided to create a separate project and to make it
open source.

Clayground is a [Qt](https://www.qt.io) based toolset that allows using C++, JavaScript
and [QML](https://doc.qt.io/qt-6/qtqml-index.html) to rapidly develop apps in a sandbox
environment with live loading capabilities.  It provides tools that try both, facilitating
learning and allowing more focused and faster development by reducing typical build and restart times significantly.

![Platformer Screenshot](res/screenshot_platformer.png)

Goals/Basic Design Decisions:

- Target Scope: Optimize for (rapid) prototyping and small/medium app development
- Focus on written source code and keyboard actions not for usage of graphical tools
- Full control: Add dedicated APIs but allow bypassing them easily (full power of C++, Qt/Qml, JavaScript)
- Don't provide (graphical) tools: Go for approaches that allow usage of freely available, popular tools like Qt Creator, Git and Inkscape
- Qt as Foundation: Don't write everything from scratch, but think how to re-combine Qt's capabilities

Main components:

- **Dojo**: Sandbox environment which is designed to be used for rapid dev, it is typically put next to a code editor/IDE, code changes are automatically applied
- **Plugins**: Different packages that can be used to build (interactive) apps
- **Examples**: Demonstrate the usage of Clayground, all examples can be either used with Dojo or standalone

Certainly, let's make it more compact while retaining the essence:

### Plugins: Your Building Blocks in Clayground

**General App Building Blocks:**

- **Text**: Handle and display text; supports CSV, JSON.
- **Storage**: Simple API for persistent data storage.
- **Network**: Effortless node discovery and P2P messaging.
- **SVG**: Inspect and use Inkscape-based SVGs for 2D scenes.
- **Canvas**: Offers a 2D coordinate system, minimizes pixel-level handling.

**Interactive Experience Plugins:**

- **Physics**: Introduces 2D physics, based on Box2D.
- **GameController**: Manages game inputs via Keyboard or Touch Screen. (Qt6 Gamepad support pending)
- **World**: Combines Canvas, Physics, and SVG to scaffold games and simulations; available in 2D (based on Clayground's Canvas) and 3D (based on Qt Quick 3D)
- **Behavior**: Defines entity behaviors like moving, path-following; currently 2D-only.

### Examples: See how problems can be solved with Clayground

A bunch of example application allow you to try it out easily:

- GUI: Visual training app for keyboard shortcuts, comes with a configuration for Inkscape.
- VisualFX: Implementation of different visual effects, includes usage of the [Qt Particle System](https://doc.qt.io/qt-6/qtquick-effects-particles.html).
- Platformer: Starting point for a platformer game.
- TopDown: Starting point for a topdown game (for example a classical RPG), comes with network support
- PluginLive: Demonstrates how to use the Clayground LiveLoader to develop a C++ plugin

### How to work with a sandbox?

1. Clone this repo and build it using CMake (Qt 6.3.0+, Qt Creator 7.0.0+). Make sure to pull the submodules `git submodule update --recursive --init`
2. Start the dojo app `claydojo --sbx <clone-dir>/sandboxes/void/Sandbox.qml`
3. Move the created windows to a location that allows you to keep them visible even when your are editing code.
4. Make changes to `<clone-dir>/sandboxes/void/Sandbox.qml` -> see the changes applied automatically
5. Press `Ctrl+G` in the app window to show the Guide/Help overlay.
6. Check out the other sandboxes in the same way :)

### How to work with multiple sandboxes?

If you pass multiple `--sbx` args (up to 5) to the dojo app, you can switch between them by using `Ctrl+(1|2|3|4|5)`.
Alternatively, you can just edit one sandbox file and the dojo app will change to the sandbox automatically if needed.
This allows you for example to work on a complete app using one `sbx` and quickly doing isolated experiments with a
minimal `sbx` like `examples/void/Sandbox.qml`.

#### Using the Logging Overlay

The sandbox comes with a logging overlay that shows all `console.log(...)` messages in a continous log view and watched properties/expressions in a sticky section. You can
easily show/hide the logging overlay by pressing `Ctrl+L` when the Sandbox Window has the focus.

<img src="res/log_overlay.png" width="50%" height="50%" alt="LogOverlay Screenshot">

Have a look at the `onMapLoaded` signal handler of the Platformer Sandbox to see how you can use them.

### How to create a deployable app?

Each of the demo sandboxes also comes with a CMake application configuration which
allows to build a standalone app. So you can just use one as a template to build your own app.

### Recommended Development Setup

To ensure a smooth development experience, we recommend the following setup:

- **Operating System**: Linux (fastest and easiest to use). Clayground has also been tested on macOS and Windows 10, but Linux is preferred for optimal performance.
- **IDE/Editor**: Qt Creator is highly recommended as it allows for easy debugging and profiling of resulting apps. Additionally, you can use Vim and VS Code for various text processing tasks.

### Detailed Steps for Setting Up the Development Environment

1. **Clone the Repository**:
   ```sh
   git clone https://github.com/MisterGC/clayground.git
   cd clayground
   git submodule update --recursive --init
   ```

2. **Install Dependencies**:
   Ensure you have the following dependencies installed:
   - CMake (version 3.20 or higher)
   - Qt (version 6.3.0 or higher)
   - Qt Creator (version 7.0.0 or higher)

3. **Build the Project**:
   ```sh
   mkdir build
   cd build
   cmake ..
   make
   ```

4. **Run the Dojo App**:
   ```sh
   ./claydojo --sbx ../sandboxes/void/Sandbox.qml
   ```

5. **Move and Arrange Windows**:
   Arrange the created windows in a way that allows you to keep them visible while editing code.

6. **Make Changes and See Results**:
   Make changes to `../sandboxes/void/Sandbox.qml` and see the changes applied automatically.

7. **Show Guide/Help Overlay**:
   Press `Ctrl+G` in the app window to show the Guide/Help overlay.

8. **Explore Other Sandboxes**:
   Check out the other sandboxes in the same way.

### Building the Project Using CMake and Qt

To build the project using CMake and Qt, follow these steps:

1. **Install CMake**:
   ```sh
   sudo apt-get install cmake
   ```

2. **Install Qt**:
   Download and install Qt from the official [Qt website](https://www.qt.io/download).

3. **Configure the Project**:
   ```sh
   mkdir build
   cd build
   cmake ..
   ```

4. **Build the Project**:
   ```sh
   make
   ```

5. **Run the Dojo App**:
   ```sh
   ./claydojo --sbx ../sandboxes/void/Sandbox.qml
   ```

### Starting the Dojo App and Working with Sandboxes

The dojo app is designed to provide a sandbox environment for rapid development. Follow these steps to start the dojo app and work with sandboxes:

1. **Start the Dojo App**:
   ```sh
   ./claydojo --sbx <path-to-sandbox-file>
   ```

2. **Move and Arrange Windows**:
   Arrange the created windows in a way that allows you to keep them visible while editing code.

3. **Make Changes and See Results**:
   Make changes to the specified sandbox file and see the changes applied automatically.

4. **Show Guide/Help Overlay**:
   Press `Ctrl+G` in the app window to show the Guide/Help overlay.

5. **Switch Between Sandboxes**:
   If you pass multiple `--sbx` args (up to 5) to the dojo app, you can switch between them by using `Ctrl+(1|2|3|4|5)`.

6. **Using the Logging Overlay**:
   The sandbox comes with a logging overlay that shows all `console.log(...)` messages in a continuous log view and watched properties/expressions in a sticky section. You can easily show/hide the logging overlay by pressing `Ctrl+L` when the Sandbox Window has the focus.

Feel free to contact me, create issues or to contribute :)

Enjoy life,<br>
`mgc`
