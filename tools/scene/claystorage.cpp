// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claystorage.h"

#include <QDir>
#include <QQmlEngine>

namespace ClayScene {

QString storageDir()
{
    const QString override = qEnvironmentVariable(StorageDirEnvVar);
    if (!override.isEmpty())
        return override;
    return QDir::homePath() + QStringLiteral("/.clayground");
}

void applyStorageDir(QQmlEngine* engine)
{
    if (engine)
        engine->setOfflineStoragePath(storageDir());
}

} // namespace ClayScene
