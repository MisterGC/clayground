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
#include "svginspector.h"
#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>

SvgInspector::SvgInspector()
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &SvgInspector::onFileChanged,
            static_cast<Qt::ConnectionType>(Qt::AutoConnection | Qt::UniqueConnection));
}

void SvgInspector::onFileChanged(const QString& /*path*/)
{
    introspect();
}

void SvgInspector::processShape(QXmlStreamReader& xmlReader,
                              QXmlStreamReader::TokenType& token,
                              bool& currentTokenProcessed,
                              const float& heightWu)
{
    auto nam = xmlReader.name();
    if (nam == "rect")
    {
        auto attribs = xmlReader.attributes();
        auto x = attribs.value("x").toFloat();
        auto y = attribs.value("y").toFloat();
        auto width = attribs.value("width").toFloat();
        auto height = attribs.value("height").toFloat();
        auto comp = attribs.value("id").toString().split("-").first();
        auto customInfo = QString("");
        auto ok = xmlReader.readNextStartElement();
        if (ok && xmlReader.name() == "desc") {
            xmlReader.readNext();
            customInfo = xmlReader.text().toString();
        }
        else {
            token = xmlReader.tokenType();
            currentTokenProcessed = false;
        }
        emit rectangle(comp, x, heightWu - y, width, height,  customInfo);
    }
    else if (nam == "circle")
    {
        auto attribs = xmlReader.attributes();
        auto x = attribs.value("cx").toFloat();
        auto y = attribs.value("cy").toFloat();
        auto radius = attribs.value("r").toFloat();
        auto comp = attribs.value("id").toString().split("-").first();
        auto customInfo = QString("");
        auto ok = xmlReader.readNextStartElement();
        if (ok && xmlReader.name() == "desc") {
            xmlReader.readNext();
            customInfo = xmlReader.text().toString();
        }
        else {
            token = xmlReader.tokenType();
            currentTokenProcessed = false;
        }
        emit circle(comp, x, heightWu - y, radius, customInfo);
    }
}

void SvgInspector::resetFileObservation()
{
    if (!fileObserver_.files().isEmpty())
        fileObserver_.removePaths(fileObserver_.files());
    fileObserver_.addPath(source_);
}

QString SvgInspector::source() const
{
    return source_;
}

void SvgInspector::introspect()
{
    auto pathToSvg = source_;

    QFile xmlFile(pathToSvg);
    if (!xmlFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCritical() << "Error unable to open " << pathToSvg;
        return;
    }
    QXmlStreamReader xmlReader(&xmlFile);

    auto heightWu = 0.0f;

    // Can be used to avoid reading a further element if
    // logic has not used the current one and dispatching should be done
    auto currentTokenProcessed = true;
    auto token = QXmlStreamReader::StartElement;
    while(!xmlReader.atEnd() && !xmlReader.hasError())
    {
        if (currentTokenProcessed) token = xmlReader.readNext();
        else currentTokenProcessed = true;

        auto nam = xmlReader.name();
        if(token == QXmlStreamReader::StartElement)
        {
            if (nam == "svg") {
                auto attribs = xmlReader.attributes();
                auto wAttr = attribs.value("width");
                if (!wAttr.endsWith("mm")) qCritical() << "Only mm as unit is supported for SVG Inspection.";
                auto widthWu = static_cast<int>(wAttr.left(wAttr.length()-2).toFloat());
                auto hAttr = attribs.value("height");
                heightWu = static_cast<int>(hAttr.left(hAttr.length()-2).toFloat());
                emit begin(widthWu, heightWu);
            }
            else if (nam == "g") {
                auto attribs = xmlReader.attributes();
                auto lbl = attribs.value("inkscape:label").toString();
                emit beginGroup(lbl);
            }
            else processShape(xmlReader, token, currentTokenProcessed, heightWu);
        }
        else if (token == QXmlStreamReader::EndElement &&
                 nam == "g") {
            endGroup();
        }
    }

    if(xmlReader.hasError())
        qCritical() << "Error while processing XML: " << xmlReader.errorString();

    xmlReader.clear();
    xmlFile.close();
    emit end();
}

void SvgInspector::setSource(const QString &pathToSvg)
{
    if (pathToSvg == source_) return;

    source_ = pathToSvg;
    resetFileObservation();
    emit sourceChanged();
    introspect();
}
