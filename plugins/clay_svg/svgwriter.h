// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAY_SVG_WRITER_H
#define CLAY_SVG_WRITER_H 

#include <QObject>
#include <QFile>
#include <QPointF>
#include <QList>
#include <memory>

namespace simple_svg {class Document;}

class SvgWriter: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)

public:
    SvgWriter();
    ~SvgWriter();

public slots:
    void begin(float widthWu, float heightWu);

    void rectangle(double x,
                   double y,
                   double width,
                   double height, const QString& description);

    void circle(double x,
                double y,
                double radius, const QString& description);

    void polygon(QVariantList points,
            const QString& description);

    void polyline(QVariantList points,
            const QString& description);

    void end();

signals:
    void pathChanged();

private:
    void setPath(const QString& pathToSvg);
    QString path() const;

private:
    std::unique_ptr<simple_svg::Document> document_;
    QString pathToSvg_;
};
#endif
