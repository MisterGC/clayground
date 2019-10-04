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
#ifndef CLAY_RESTARTER_H
#define CLAY_RESTARTER_H 
#include <clayfilesysobserver.h>

#include <QLoggingCategory>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <atomic>
#include <condition_variable>
#include <map>
#include <memory>
#include <mutex>

class ClayRestarter: public QObject 
{
    Q_OBJECT

public:
    ClayRestarter(QObject* parent = nullptr);
    ~ClayRestarter();
    void addDynPluginDepedency(const QString &srcPath, const QString &binPath);

public slots:
    void run();

private slots:
    void onSbxOutput();
    void onFileSysChange(const QString& path);
    void onTimeToRestart();

signals:
    void restarted();

private:
    std::mutex mutex_;
    std::condition_variable restarterStopped_;
    std::atomic_bool shallStop_;
    std::atomic_bool shallRestart_;
    std::unique_ptr<QProcess> sbx_;
    ClayFileSysObserver fileObserver_;
    std::map<QString, QString> sourceToBuildDir_;
    QStringList buildWaitList_;
    QTimer restart_;
    QLoggingCategory logCat_;
};
#endif
