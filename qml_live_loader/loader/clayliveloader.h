/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include <clayfilesysobserver.h>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QSqlDatabase>
#include <QTimer>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sandboxFile READ sandboxFile NOTIFY sandboxFileChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir NOTIFY sandboxDirChanged)
    Q_PROPERTY(QString altMessage READ altMessage NOTIFY altMessageChanged)

public:
    explicit ClayLiveLoader(QObject *parent = nullptr);

    QString sandboxFile() const;
    QString sandboxDir() const;
    void addDynImportDir(const QString& path);
    void addDynPluginDir(const QString& path);
    void show();
    QString altMessage() const;
    void setAltMessage(const QString &altMessage);

signals:
    void sandboxFileChanged();
    void sandboxDirChanged();
    void altMessageChanged();
    void restarted();

private slots:
    void onFileChanged(const QString& path);
    void onFileAdded(const QString& path);
    void onFileRemoved(const QString& path);
    void onEngineWarnings(const QList<QQmlError>& warnings);
    void onTimeToRestart();

private:
    void setSandboxFile(const QString &path);
    void clearCache();
    bool isQmlPlugin(const QString &path) const;
    void storeValue(const QString& key, const QString& value);
    void storeErrors(const QString& errors);

private:
    QQmlApplicationEngine engine_;
    ClayFileSysObserver fileObserver_;
    QString sandboxFile_;
    QSqlDatabase statsDb_;
    QTimer reload_;
    QString altMessage_;
};

#endif
