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
#ifndef POPULATOR_H
#define POPULATOR_H
#include <QObject>
#include <QFileSystemWatcher>
#include <QXmlStreamReader>

class SvgInspector: public QObject
{
    Q_OBJECT

public:
    SvgInspector();

public slots:
    void setSource(const QString& pathToSvg);
    QString source() const;

signals:
    void sourceChanged();
    void begin(float widthWu, float heightWu);
    void beginGroup(const QString& grpName);
    void rectangle(const QString& componentName, float x, float y, float width, float height, const QString& description);
    void circle(const QString& componentName, float x, float y, float radius, const QString& description);
    void endGroup();
    void end();

private slots:
    void onFileChanged(const QString &path);

private:
    void introspect();
    void processShape(QXmlStreamReader &reader,
                      QXmlStreamReader::TokenType &token,
                      bool &currentTokenProcessed,
                      const float &heightWu);
    void resetFileObservation();

private:
    QFileSystemWatcher fileObserver_;
    QString source_;
};
#endif
