// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ClayShaderBaker - compiles a sandbox's own shaders for the live tools.
//
// A Qt 6 ShaderEffect only takes precompiled .qsb files. Plugins bake theirs
// at build time with qt_add_shaders(), but a sandbox is loaded straight from
// its source directory, so a game that wanted its own shader had nothing to
// point `fragmentShader:` at. The live tools (dojo loader, clayrender) close
// that gap: every `*.frag` / `*.vert` under the sandbox directory is baked
// with Qt's `qsb` into `<name>.frag.qsb` right beside it - the same relative
// path qt_add_shaders() gives it in an app's resources, so one QML line works
// in both.
//
// The targets match qt_add_shaders()' defaults (GLSL 100 es/120/150, HLSL 50,
// MSL 12), so a shader that bakes here also bakes for the WebAssembly build.

#pragma once

#include <QString>
#include <QStringList>

class ClayShaderBaker
{
public:
    // True for the shader stages a sandbox may bake (.frag, .vert).
    static bool isShaderSource(const QString& path);

    // The qsb executable: $CLAY_QSB when set, else the one shipped with the
    // Qt the tool runs against. Empty when none can be found.
    static QString qsbTool();

    // Bake one source into <source>.qsb. On failure `error` carries qsb's
    // own diagnostics (file, line, message), ready to show verbatim.
    static bool bake(const QString& source, QString* error = nullptr);

    struct Result {
        int baked = 0;
        QStringList errors;
    };

    // Bake every shader source under `dir` (recursively, skipping .clay/)
    // whose .qsb is missing or older than the source.
    static Result bakeStale(const QString& dir);
};
