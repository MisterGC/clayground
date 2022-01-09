// (c) Clayground Contributors - zlib license, see "LICENSE" file

#include "svgwriter.h"
#include <simple-svg-writer/simple_svg.h>
#include <QVariant>
#include <QFile>
#include <QTextStream>
#include <QDebug>

using namespace simple_svg;

SvgWriter::SvgWriter() : document_(new Document(""))
{}

SvgWriter::~SvgWriter() = default;

void SvgWriter::begin(float widthWu, float heightWu)
{
    Dimensions dimensions(static_cast<double>(widthWu),
                          static_cast<double>(heightWu));
    document_.reset(new Document(pathToSvg_.toStdString(),
                                 Layout(dimensions, Layout::mm, Layout::BottomLeft)));
}

void SvgWriter::rectangle(double x,
                          double y,
                          double width,
                          double height,
                          const QString &description)
{
    auto r = Rectangle(Point(x, y), width, height, Color::Black);
    r.setDescription(description.toHtmlEscaped().toStdString());
    *document_ << r;
}

void SvgWriter::circle(double x,
                       double y,
                       double radius,
                       const QString & description)
{
    auto r = Circle(Point(x,y), radius, Color::Black);
    r.setDescription(description.toHtmlEscaped().toStdString());
    *document_ << r;
}

namespace {
template<class P>
void addAllPoints(P& poly, QVariantList points)
{
    for (auto& v: points)
    {
        if(v.canConvert<QPointF>())
        {
            auto p = v.toPointF();
            poly << Point(p.x(), p.y());
        }
    }
}
}

void SvgWriter::polygon(QVariantList points, const QString &description)
{
    auto poly = Polygon(Color::Black, Color::Black);
    addAllPoints<Polygon>(poly, points);
    poly.setDescription(description.toHtmlEscaped().toStdString());
    *document_ << poly;
}

void SvgWriter::polyline(QVariantList points, const QString &description)
{
    auto poly = Polyline(Color::Transparent, Color::Black);
    addAllPoints<Polyline>(poly, points);
    poly.setDescription(description.toHtmlEscaped().toStdString());
    *document_ << poly;
}

void SvgWriter::end()
{
    document_->save();
}

void SvgWriter::setPath(const QString& pathToSvg)
{
    if (pathToSvg != pathToSvg_) {
        pathToSvg_ = pathToSvg;
        emit pathChanged();
    }
}

QString SvgWriter::path() const
{
    return pathToSvg_;
}
