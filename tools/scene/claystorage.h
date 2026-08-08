// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QString>

class QQmlEngine;

namespace ClayScene {

// The environment variable that carries a storage override, so a headless
// host can keep its writes out of the person's store (issue #200).
//
// Everything a sandbox persists through QML LocalStorage - which is what
// Clayground.Storage's KeyValueStore and therefore LabPrefs are built on -
// lands in one directory per engine. There is exactly one shared default
// (~/.clayground), which is why a scripted render that flipped the theme
// used to leave the next dojo session dark: the render and the session were
// writing the same file.
//
// A host that wants isolation sets this variable before it builds its engine
// and points it somewhere throwaway; a host that wants the person's real
// settings leaves it unset. Nothing in QML has to know - the redirection
// happens at the engine, so every LocalStorage user honors it at once.
constexpr const char* StorageDirEnvVar = "CLAY_STORAGE_DIR";

// Where this process keeps QML LocalStorage databases: the value of
// CLAY_STORAGE_DIR when it is set and non-empty, otherwise the shared
// ~/.clayground.
QString storageDir();

// Convenience for hosts: storageDir() applied to the engine. Call it before
// loading anything - an engine that already opened a database has committed
// to a location.
void applyStorageDir(QQmlEngine* engine);

} // namespace ClayScene
