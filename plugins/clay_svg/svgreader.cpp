// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "svgreader.h"

#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>
#include <QPointF>
#include <QRegularExpression>
#include <QStringView>
#include <QVariant>

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

void SvgReader::onPath(const QString& id,
                       const QString& dAttr,
                       const QString& descr,
                       double heightWu,
                       const QString& fillColor,
                       const QString& strokeColor)
{
    auto const dPoly = dAttr.split(" ");

    QPointF refPos(0.,0.);
    QChar cmd = 'M';
    QVector<QPointF> points;
    auto isPolygon = false;

    QRegularExpression supportedCmds("[MmLlVvHhZz]");
    for (auto const& t: dPoly){
        if (supportedCmds.match(t).hasMatch()){
            cmd = *t.begin();
            if (cmd == 'Z' || cmd == 'z') isPolygon = true;
        }
        else {
            auto const nums = t.split(",");
            auto isnum = false;
            if (nums.empty()) {qCritical() << "svg: Expected number(s) but got none."; return;}
            auto const n1 = nums[0].toFloat(&isnum);
            if (!isnum) {qCritical() << "svg: Expected a number but got " << t << "."; return;}
            auto const n2 = nums.length() > 1 ? nums[1].toFloat() : 0.0;
            using Point = QPointF;
            // L and M cmds are treated as the same because subpaths are not (yet) supported
            switch (cmd.toLatin1()) {
                case ('L'):
                case ('M'): {refPos = Point(n1,n2);} break;
                case ('l'):
                case ('m'): {refPos = Point(refPos.x() + n1, refPos.y() + n2);} break;
                case ('V'): {refPos = Point(refPos.x(), n1);} break;
                case ('v'): {refPos = Point(refPos.x(), refPos.y() + n1);} break;
                case ('H'): {refPos = Point(n1, refPos.y());} break;
                case ('h'): {refPos = Point(refPos.x() + n1, refPos.y());} break;
            }
            points.push_back(refPos);
        }
    }

    QVariantList varPoints;
    for (auto& p: points){
        p.setY(heightWu - p.y()); // svg world to clay world units
        varPoints.push_back(applyGroupTransform(p.x(), p.y()));
    }

    if (isPolygon) emit polygon(id, varPoints, fillColor, strokeColor, descr);
    else emit polyline(id, varPoints, fillColor, strokeColor, descr);
}

void SvgReader::listToPoints(const QString& lst,
                                QVariantList& points,
                                bool absCoords,
                                double heightWu,
                                bool closePath)
{
    auto const ppairs = lst.split(" ");
    std::vector<QPointF> pData;
    for (auto const& p: ppairs) {
        if (p.trimmed().isEmpty()) continue;
        auto c = p.split(",");
        auto pnt = QPointF(c[0].toDouble(), (heightWu - c[1].toDouble()));
        pData.push_back(pnt);
    }
    if (pData.empty()) return;
    if (!absCoords) {
        for (size_t i=1; i<pData.size(); ++i){
            auto& p = pData[i];
            auto const& prev = pData[i-1];
            p.setX(p.x() + prev.x());
            p.setY(p.y() - (heightWu - prev.y()));
        }
    }
    for (auto const& p: pData) points.append(QVariant(applyGroupTransform(p.x(), p.y())));
    if (closePath) points.push_back(QVariant(points.front()));
}

QString SvgReader::fetchDescr(QXmlStreamReader &reader,
                              QXmlStreamReader::TokenType &token,
                              bool &currentTokenProcessed)
{
    auto descr = QString("");
    auto const ok = reader.readNextStartElement();
    if (ok && reader.name().toString() == "desc") {
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

namespace
{
void extractColors(const QXmlStreamAttributes& attribs, QString& fillColor, QString& strokeColor) {
    fillColor = "#000000";  // Default values
    strokeColor = "none";

    if (attribs.hasAttribute("fill")) {
        fillColor = attribs.value("fill").toString();
    } else if (attribs.hasAttribute("style")) {
        QRegularExpression reFill("fill:([^;]+)");
        auto matchFill = reFill.match(attribs.value("style").toString());
        if (matchFill.hasMatch()) {
            fillColor = matchFill.captured(1);
        }
    }

    if (attribs.hasAttribute("stroke")) {
        strokeColor = attribs.value("stroke").toString();
    } else if (attribs.hasAttribute("style")) {
        QRegularExpression reStroke("stroke:([^;]+)");
        auto matchStroke = reStroke.match(attribs.value("style").toString());
        if (matchStroke.hasMatch()) {
            strokeColor = matchStroke.captured(1);
        }
    }
}

}

void SvgReader::processShape(QXmlStreamReader& xmlReader,
                              QXmlStreamReader::TokenType& token,
                              bool& currentTokenProcessed,
                              const float& heightWu)
{
    auto const fetchDescr = [&xmlReader, &token, &currentTokenProcessed]()
    {
        auto descr = QString("");
        auto const ok = xmlReader.readNextStartElement();
        if (ok && xmlReader.name() == QString("desc")) {
            xmlReader.readNext();
            descr = xmlReader.text().toString();
        }
        else {
            token = xmlReader.tokenType();
            currentTokenProcessed = false;
        }
        return descr;
    };

    auto const nam = xmlReader.name().toString();
    auto const attribs = xmlReader.attributes();
    auto const id = attribs.value("id").toString();
    QString fillColor, strokeColor;
    extractColors(attribs, fillColor, strokeColor);
    if (nam == "rect")
    {
        auto const p = applyGroupTransform(attribs.value("x").toFloat(), attribs.value("y").toFloat());
        auto const width = attribs.value("width").toFloat();
        auto const height = attribs.value("height").toFloat();
        emit rectangle(id, p.x(), heightWu - p.y(), width, height,
                       fillColor, strokeColor, fetchDescr());
    }
    else if (nam == "circle")
    {
        auto const p = applyGroupTransform(attribs.value("cx").toFloat(), attribs.value("cy").toFloat());
        auto const radius = attribs.value("r").toFloat();
        emit circle(id, p.x(), heightWu - p.y(), radius,
                    fillColor, strokeColor, fetchDescr());
    }
    else if (nam == "polygon" || nam == "polyline")
    {
        QVariantList points;
        auto const isPolygon = (nam == "polygon");
        auto const lst = attribs.value("points").toString();
        listToPoints(lst, points, true, heightWu, isPolygon);
        if (isPolygon)
            emit polygon(id, points, fillColor, strokeColor, fetchDescr());
        else
            emit polyline(id, points, fillColor, strokeColor,  fetchDescr());
    }
    else if (nam == "path")
    {
        auto const d = attribs.value("d").toString();
        onPath(id, d, fetchDescr(), heightWu, fillColor, strokeColor);
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
    auto const pathToSvg = source_;

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

        auto const nam = xmlReader.name().toString();
        if(token == QXmlStreamReader::StartElement && !defsSection)
        {
            if (nam == "svg") {
                auto const attribs = xmlReader.attributes();
                auto const wAttr = attribs.value("width").toString();
                if (!wAttr.endsWith("mm")) qCritical() << "Only mm as unit is supported for SVG Inspection.";
                auto const widthWu = wAttr.left(wAttr.length()-2).toFloat();
                auto const hAttr = attribs.value("height");
                heightWu = hAttr.left(hAttr.length()-2).toFloat();
                emit begin(widthWu, heightWu);
            }
            else if (nam == "g") {
                auto const attribs = xmlReader.attributes();
                auto const id = attribs.value("id").toString();
                auto translate = QPointF(0., 0.);
                if (attribs.hasAttribute("transform")){
                    auto const transf = attribs.value("transform").toString();
                    auto const t = QString("translate(");
                    if (transf.startsWith(t)){
                        auto const vals = transf.mid(t.length(),transf.length() - (t.length()+1)).split(",");
                        translate = QPointF(vals[0].toFloat(), vals[1].toFloat());
                    }
                }
                groupTranslates_.push(translate);
                auto const descr = fetchDescr(xmlReader, token, currentTokenProcessed);
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
