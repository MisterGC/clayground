#include "populator.h"
#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>

void Populator::onSvgChanged(const QString &path)
{
    // INFO Re-add file as otherwise (at least on Linux)
    // further changes are not recognized
    svgObserver_.removePath(path);
    setPopulationModel(path);
    svgObserver_.addPath(path);
    syncWithSvg();
}

void Populator::syncWithSvg()
{
    if (!svgObserver_.files().empty())
    {
        auto pathToSvg = svgObserver_.files().first();

        QFile xmlFile(pathToSvg);
        if (!xmlFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qCritical() << "Error unable to open " << pathToSvg;
            return;
        }
        QXmlStreamReader xmlReader(&xmlFile);

        bool readingMapContent = false;

        // Needed to flip the coordinates as world coord system starts in
        // lower left corner not upper left (!)
        auto heightWu = 0.0f;
        while(!xmlReader.atEnd() && !xmlReader.hasError())
        {
            auto token = xmlReader.readNext();
            if(token == QXmlStreamReader::StartElement)
            {
                auto nam = xmlReader.name();
                if (nam == "svg") {
                    auto attribs = xmlReader.attributes();
                    auto widthPx = attribs.value("width").toInt();
                    auto heightPx = attribs.value("height").toInt();
                    auto viewBox = attribs.value("viewBox").toString().split(" ");
                    auto widthWu = viewBox[2].toFloat();
                    heightWu = viewBox[3].toFloat();
                    emit aboutToPopulate(widthWu, heightWu, widthPx, heightPx);
                }
                else if (nam == "g") {
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
                    auto width = attribs.value("width").toFloat();
                    auto height = attribs.value("height").toFloat();

                    auto comp = attribs.value("id").toString().split("-").first();
                    qDebug() << "xSvg: " << x << " ySvg: " << y;
                    emit createItemAt(comp, x, heightWu - y, width, height);
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
}

void Populator::setPopulationModel(const QString &pathToSvg)
{
    connect(&svgObserver_, &QFileSystemWatcher::fileChanged,
            this, &Populator::onSvgChanged,
            static_cast<Qt::ConnectionType>(Qt::AutoConnection | Qt::UniqueConnection));
    svgObserver_.removePaths(svgObserver_.files());
    svgObserver_.addPath(pathToSvg);
    syncWithSvg();
}
