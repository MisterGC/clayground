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
        QString customInfo = "";
        bool ok = xmlReader.readNextStartElement();
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
        QString customInfo = "";
        bool ok = xmlReader.readNextStartElement();
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
    bool currentTokenProcessed = true;
    QXmlStreamReader::TokenType token = QXmlStreamReader::StartElement;
    while(!xmlReader.atEnd() && !xmlReader.hasError())
    {
        if (currentTokenProcessed) token = xmlReader.readNext();
        else currentTokenProcessed = true;

        auto nam = xmlReader.name();
        if(token == QXmlStreamReader::StartElement)
        {
            if (nam == "svg") {
                auto attribs = xmlReader.attributes();
                auto widthPx = attribs.value("width").toInt();
                auto heightPx = attribs.value("height").toInt();
                auto viewBox = attribs.value("viewBox").toString().split(" ");
                auto widthWu = viewBox[2].toFloat();
                heightWu = viewBox[3].toFloat();
                emit begin(widthWu, heightWu, widthPx, heightPx);
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
