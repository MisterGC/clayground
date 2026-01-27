// (c) Clayground Contributors - MIT License, see "LICENSE" file
// This file imports QML modules to ensure they're available for dynamically loaded QML
// The Item is never instantiated - it just triggers plugin linking at build time

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick3D.Helpers
import QtQuick.LocalStorage
import QtMultimedia
import Clayground.Sound

Item {
    // Never used, just for module linking
}
