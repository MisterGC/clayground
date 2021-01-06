// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "svgreader.h"
#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>
#include <QPointF>

#include <string>
#include <regex>
#include <sstream>

SvgReader::SvgReader()
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &SvgReader::onFileChanged,
            static_cast<Qt::ConnectionType>(Qt::AutoConnection | Qt::UniqueConnection));
}

void SvgReader::onFileChanged(const QString& /*path*/)
{
    introspect();
}

void SvgReader::onPath(const QString& dAttr, const QString& descr, double heightWu)
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

void SvgReader::listToPoints(const QString& lst,
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
        auto pnt = QPointF(c[0].toDouble(), (heightWu - c[1].toDouble()));
        pData.push_back(pnt);
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
    for (const auto& p: pData) points.append(applyGroupTransform(p.x(), p.y()));
    if (closePath) points.push_back(points.front());
}

QString SvgReader::fetchDescr(QXmlStreamReader &reader,
                              QXmlStreamReader::TokenType &token,
                              bool &currentTokenProcessed)
{
    auto descr = QString("");
    auto ok = reader.readNextStartElement();
    if (ok && reader.name() == "desc") {
        reader.readNext();
        descr = reader.text().toString();
    }
    else {
        token = reader.tokenType();
        currentTokenProcessed = false;
    }
    return descr;
}

QPointF SvgReader::applyGroupTransform(float x, float y) const
{
    auto pt = QPointF(x, y);
    for (const auto& t: groupTranslates_) pt += t;
    return pt;
};


void SvgReader::processShape(QXmlStreamReader& xmlReader,
                              QXmlStreamReader::TokenType& token,
                              bool& currentTokenProcessed,
                              const float& heightWu)
{

    auto nam = xmlReader.name();
    auto attribs = xmlReader.attributes();
    if (nam == "rect")
    {
        auto p = applyGroupTransform(attribs.value("x").toFloat(), attribs.value("y").toFloat());
        auto width = attribs.value("width").toFloat();
        auto height = attribs.value("height").toFloat();
        emit rectangle(p.x(), heightWu - p.y(), width, height,  fetchDescr(xmlReader, token, currentTokenProcessed));
    }
    else if (nam == "circle")
    {
        auto p = applyGroupTransform(attribs.value("cx").toFloat(), attribs.value("cy").toFloat());
        auto radius = attribs.value("r").toFloat();
        emit circle(p.x(), heightWu - p.y(), radius, fetchDescr(xmlReader, token, currentTokenProcessed));
    }
    else if (nam == "polygon" || nam == "polyline")
    {
        QVariantList points;
        auto isPolygon = (nam == "polygon");
        auto lst = attribs.value("points").toString();
        listToPoints(lst, points, true, heightWu, isPolygon);
        if (isPolygon)
            emit polygon(points, fetchDescr(xmlReader, token, currentTokenProcessed));
        else
            emit polyline(points, fetchDescr(xmlReader, token, currentTokenProcessed));
    }
    else if (nam == "path")
    {
        auto d = attribs.value("d").toString();
        onPath(d, fetchDescr(xmlReader, token, currentTokenProcessed), heightWu);
    }
}

void SvgReader::resetFileObservation()
{
    if (!fileObserver_.files().isEmpty())
        fileObserver_.removePaths(fileObserver_.files());
    if (!source_.isEmpty())
        fileObserver_.addPath(source_);
}

QString SvgReader::source() const
{
    return source_;
}

void SvgReader::introspect()
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

    auto defsSection = false;

    // Can be used to avoid reading a further element if
    // logic has not used the current one and dispatching should be done
    auto currentTokenProcessed = true;
    auto token = QXmlStreamReader::StartElement;
    while(!xmlReader.atEnd() && !xmlReader.hasError())
    {
        if (currentTokenProcessed) token = xmlReader.readNext();
        else currentTokenProcessed = true;

        auto nam = xmlReader.name();
        if(token == QXmlStreamReader::StartElement && !defsSection)
        {
            if (nam == "svg") {
                auto attribs = xmlReader.attributes();
                auto wAttr = attribs.value("width");
                if (!wAttr.endsWith("mm")) qCritical() << "Only mm as unit is supported for SVG Inspection.";
                auto widthWu = static_cast<float>(wAttr.left(wAttr.length()-2).toFloat());
                auto hAttr = attribs.value("height");
                heightWu = static_cast<float>(hAttr.left(hAttr.length()-2).toFloat());
                emit begin(widthWu, heightWu);
            }
            else if (nam == "g") {
                auto attribs = xmlReader.attributes();
                auto id = attribs.value("id").toString();
                auto translate = QPointF(0., 0.);
                if (attribs.hasAttribute("transform")){
                    auto transf = attribs.value("transform");
                    const auto t = QString("translate(");
                    if (transf.startsWith(t)){
                        auto vals = transf.mid(t.length(),transf.length() - (t.length()+1)).split(",");
                        translate = QPointF(vals[0].toFloat(), vals[1].toFloat());
                    }
                }
                groupTranslates_.push(translate);
                auto descr = fetchDescr(xmlReader, token, currentTokenProcessed);
                emit beginGroup(id, descr);
            }
            else if (nam == "defs") defsSection = true;
            else processShape(xmlReader, token, currentTokenProcessed, heightWu);
        }
        else if (token == QXmlStreamReader::EndElement){
            if (nam == "g") {
                groupTranslates_.pop();
                emit endGroup();
            }
            else if (nam == "defs")  defsSection = false;
        }
    }

    if(xmlReader.hasError())
        qCritical() << "Error while processing XML: " << xmlReader.errorString();

    xmlReader.clear();
    xmlFile.close();
    emit end();
}

void SvgReader::setSource(const QString &pathToSvg)
{
    if (pathToSvg == source_) return;

    source_ = pathToSvg;
    resetFileObservation();
    emit sourceChanged();
    introspect();
}
