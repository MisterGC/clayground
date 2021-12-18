// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAY_SVG_READER_H
#define CLAY_SVG_READER_H
#include <QObject>
#include <QFileSystemWatcher>
#include <QXmlStreamReader>
#include <QStack>
#include <QPointF>
#include <qqmlregistration.h>

class SvgReader: public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    SvgReader();

public slots:
    void setSource(const QString& pathToSvg);
    QString source() const;

signals:
    void sourceChanged();
    void begin(float widthWu, float heightWu);
    void beginGroup(const QString& id, const QString& description);
    void rectangle(const QString& id, float x, float y, float width, float height, const QString& description);
    void circle(const QString& id, float x, float y, float radius, const QString& description);
    void polygon(const QString& id, const QVariantList& points, const QString& description);
    void polyline(const QString& id, const QVariantList& points, const QString& description);
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
    void onPath(const QString &id, const QString &dAttr, const QString &descr, double heightWu);
    void listToPoints(const QString &lst, QVariantList &points, bool absCoords, double heightWu, bool closePath);
    QString fetchDescr(QXmlStreamReader &reader, QXmlStreamReader::TokenType &token, bool &currentTokenProcessed);
    QPointF applyGroupTransform(float x, float y) const;

private:
    QFileSystemWatcher fileObserver_;
    QString source_;

    QStack<QPointF> groupTranslates_;
};
#endif
