// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAY_SVG_READER_H
#define CLAY_SVG_READER_H
#include <QObject>
#include <QFileSystemWatcher>
#include <QXmlStreamReader>

class SvgReader: public QObject
{
    Q_OBJECT

public:
    SvgReader();

public slots:
    void setSource(const QString& pathToSvg);
    QString source() const;

signals:
    void sourceChanged();
    void begin(float widthWu, float heightWu);
    void beginGroup(const QString& name, const QString& description);
    void rectangle(float x, float y, float width, float height, const QString& description);
    void circle(float x, float y, float radius, const QString& description);
    void polygon(const QVariantList& points, const QString& description);
    void polyline(const QVariantList& points, const QString& description);
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
    void onPath(const QString &dAttr, const QString &descr, double heightWu);
    void listToPoints(const QString &lst, QVariantList &points, bool absCoords, double heightWu, bool closePath);
    QString fetchDescr(QXmlStreamReader &reader, QXmlStreamReader::TokenType &token, bool &currentTokenProcessed);

private:
    QFileSystemWatcher fileObserver_;
    QString source_;
};
#endif
