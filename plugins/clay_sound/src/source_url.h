// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Where a player's `source` url points, shared by the players that load
// a JSON file and hot-reload it (SongPlayer, SfxPlayer): a relative url
// resolves against the QML file that set it, a local or qrc url is read
// from disk (and can be watched), anything else is fetched.

#ifndef CLAY_SOUND_SOURCE_URL_H
#define CLAY_SOUND_SOURCE_URL_H

#include <QString>
#include <QUrl>

class QObject;

namespace clay::sound {

// `url` resolved against the QML context of `ctx`; local urls as given.
QUrl resolveSourceUrl(QObject *ctx, const QUrl &url);

// True for an empty, file, qrc or scheme-less url: one read from disk.
bool isLocalSourceUrl(const QUrl &url);

// The path QFile opens for a local url (":/..." for qrc).
QString sourceUrlToLocalPath(const QUrl &url);

} // namespace clay::sound

#endif // CLAY_SOUND_SOURCE_URL_H
