#include "populator.h"
#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>

void Populator::loadSvgPopulationModel(const QString &pathToSvg)
{
    QFile xmlFile(pathToSvg);
    if (!xmlFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCritical() << "Error unable to open " << pathToSvg;
        return;
    }
    QXmlStreamReader xmlReader(&xmlFile);

    bool readingMapContent = false;
    while(!xmlReader.atEnd() && !xmlReader.hasError())
    {
        auto token = xmlReader.readNext();
        if(token == QXmlStreamReader::StartElement)
        {
            auto nam = xmlReader.name();
            if(nam == "g") {
                auto attribs = xmlReader.attributes();
                auto lbl = attribs.value("inkscape:label").toString();
                if (lbl == "Map") readingMapContent = true;
                else if (lbl == "Legend") readingMapContent = false;
            }
            else if (readingMapContent && nam == "rect")
            {
                auto attribs = xmlReader.attributes();
                auto x = attribs.value("x").toFloat();
                auto y = attribs.value("y").toFloat();
                auto comp = attribs.value("id").toString();
                // TODO Convert SVG coords to pixel coords
                emit createItemAt(comp, (int)x, (int)y);
            }
        }
    }

    if(xmlReader.hasError())
    {
        qCritical() << "Error while processing XML: " << xmlReader.errorString();
    }

    xmlReader.clear();
    xmlFile.close();
}
