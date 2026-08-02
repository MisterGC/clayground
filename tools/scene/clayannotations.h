// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

namespace ClayScene {

// The annotation store (issue #182): the user's spatial remarks about a
// running sandbox, at <sandboxDir>/.clay/crew/annotations/index.json.
//
// Two writers share this file. The overlay owns creation and the fields that
// describe what the user framed (rect, note, scope, view, created,
// generation); the inspector owns status, addressedNote, addressedAt, anchor
// and crop. Neither may write the whole document from a copy it read earlier -
// every write here re-reads, patches, and commits atomically, so a slow round
// trip on one side cannot roll back the other.
//
// A missing file is an empty store, never an error: it only exists once
// something has been annotated.
namespace Annotations {

// <crewDir>/annotations/index.json
QString indexPath(const QString& crewDir);
// <crewDir>/annotations - where the crops live too.
QString dir(const QString& crewDir);

// The schema version this build writes and understands.
constexpr int VERSION = 1;

// Every annotation, in store order. `error` is set only for a file that
// exists but cannot be read or parsed - a store that is simply not there
// yet returns an empty array with no error.
QJsonArray load(const QString& crewDir, QString* error = nullptr);

// The filtered view. `status` empty means any; `sinceGeneration` < 0 means
// any; `limit` <= 0 means no limit.
QJsonArray filter(const QJsonArray& all, const QString& status,
                  int sinceGeneration, int limit);
QJsonArray list(const QString& crewDir, const QString& status,
                int sinceGeneration, int limit, QString* error = nullptr);

// Re-read, apply `patch` to the entry with this id, commit atomically. Only
// the keys in `patch` change; everything else the entry carries survives,
// including fields this build has never heard of. False (with `error`) when
// there is no such entry - a silent no-op would read as success.
bool patchEntry(const QString& crewDir, const QString& id,
                const QJsonObject& patch, QString* error = nullptr);

// The crop path an annotation with this id uses, relative to <crewDir> (the
// form stored in the index) and as an absolute path.
QString cropRelativePath(const QString& id);
QString cropAbsolutePath(const QString& crewDir, const QString& relative);

} // namespace Annotations
} // namespace ClayScene
