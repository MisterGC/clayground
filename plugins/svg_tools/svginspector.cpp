// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "svginspector.h"
#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>
#include <QPointF>

#include <string>
#include <regex>
#include <sstream>

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

void SvgInspector::onPath(const QString& dAttr, const QString& descr, double heightWu)
{
    const auto dPoly = dAttr.toStdString();

    using namespace std;
    const auto number = string("(?:\\s*[-]?\\d+(?:\\.\\d+)?\\s*)");
    stringstream strstr;
    strstr << "([mM])" << "((?:" << number << "," << number << ")+)" << "([zZ]?)";
    const regex base_regex(strstr.str());
    smatch base_match;
    if (regex_match(dPoly, base_match, base_regex) &&
        base_match.size() == 4 )
    {
        const auto m = base_match[1].str();
        const auto pList = base_match[2].str();
        const auto z = base_match[3].str();

        auto lst = QString::fromStdString(pList).trimmed();
        QVariantList points;
        auto isPolygon = !z.empty();
        listToPoints(lst, points, m == "M", heightWu, isPolygon);
        if (isPolygon)
            emit polygon(points, descr);
        else
            emit polyline(points, descr);
    }
    else {
        qWarning() << "Skipping unsupported path "
                   << dAttr;
    }
}

void SvgInspector::listToPoints(const QString& lst,
                                QVariantList& points,
                                bool absCoords,
                                double heightWu,
                                bool closePath)
{
    auto ppairs = lst.split(" ");
    std::vector<QPointF> pData;
    for (auto& p: ppairs) {
        if (p.trimmed().isEmpty()) continue;
        auto c = p.split(",");
        auto point = QPointF(c[0].toDouble(),
                (heightWu - c[1].toDouble()));
        pData.push_back(point);
    }
    if (pData.empty()) return;
    if (!absCoords) {
        for (size_t i=1; i<pData.size(); ++i){
            auto& p = pData[i];
            auto& prev = pData[i-1];
            p.setX(p.x() + prev.x());
            p.setY(p.y() - (heightWu - prev.y()));
        }
    }
    for (const auto& p: pData) points.append(p);
    if (closePath) points.push_back(pData.front());
}


void SvgInspector::processShape(QXmlStreamReader& xmlReader,
                              QXmlStreamReader::TokenType& token,
                              bool& currentTokenProcessed,
                              const float& heightWu)
{
    auto fetchDescr = [&xmlReader, &token, &currentTokenProcessed]()
    {
        auto descr = QString("");
        auto ok = xmlReader.readNextStartElement();
        if (ok && xmlReader.name() == "desc") {
            xmlReader.readNext();
            descr = xmlReader.text().toString();
        }
        else {
            token = xmlReader.tokenType();
            currentTokenProcessed = false;
        }
        return descr;
    };

    auto nam = xmlReader.name();
    auto attribs = xmlReader.attributes();
    if (nam == "rect")
    {
        auto x = attribs.value("x").toFloat();
        auto y = attribs.value("y").toFloat();
        auto width = attribs.value("width").toFloat();
        auto height = attribs.value("height").toFloat();
        auto descr = QString("");
        emit rectangle(x, heightWu - y, width, height,  fetchDescr());
    }
    else if (nam == "circle")
    {
        auto x = attribs.value("cx").toFloat();
        auto y = attribs.value("cy").toFloat();
        auto radius = attribs.value("r").toFloat();
        emit circle(x, heightWu - y, radius, fetchDescr());
    }
    else if (nam == "polygon" || nam == "polyline")
    {
        QVariantList points;
        auto isPolygon = (nam == "polygon");
        auto lst = attribs.value("points").toString();
        listToPoints(lst, points, true, heightWu, isPolygon);
        if (isPolygon)
            emit polygon(points, fetchDescr());
        else
            emit polyline(points, fetchDescr());
    }
    else if (nam == "path")
    {
        auto d = attribs.value("d").toString();
        onPath(d, fetchDescr(), heightWu);
    }
}

void SvgInspector::resetFileObservation()
{
    if (!fileObserver_.files().isEmpty())
        fileObserver_.removePaths(fileObserver_.files());
    if (!source_.isEmpty())
        fileObserver_.addPath(source_);
}

QString SvgInspector::source() const
{
    return source_;
}

void SvgInspector::introspect()
{
    if (source_.isEmpty()) return;
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
