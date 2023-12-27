// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

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

    // Document start/end signals
    void begin(float widthWu, float heightWu);
    void end();

    // Group start/end signals
    void beginGroup(const QString& id, const QString& description);
    void endGroup();

    // Supported shape types, for each one there is a
    // dedicated signal

    void rectangle(const QString& id,
                   float x,
                   float y,
                   float width,
                   float height,
                   const QString& fillColor,
                   const QString& strokeColor,
                   const QString& description);

    void circle(const QString& id,
                float x,
                float y,
                float radius,
                const QString& fillColor,
                const QString& strokeColor,
                const QString& description);

    void polygon(const QString& id,
                 const QVariantList& points,
                 const QString& fillColor,
                 const QString& strokeColor,
                 const QString& description);

    void polyline(const QString& id,
                  const QVariantList& points,
                  const QString& fillColor,
                  const QString& strokeColor,
                  const QString& description);

private slots:
    void onFileChanged(const QString &path);

private:
    void introspect();
    void processShape(QXmlStreamReader &reader,
                      QXmlStreamReader::TokenType &token,
                      bool &currentTokenProcessed,
                      const float &heightWu);
    void resetFileObservation();
    void onPath(const QString &id,
                const QString &dAttr,
                const QString &descr,
                double heightWu,
                const QString& fillColor,
                const QString& strokeColor);
    void listToPoints(const QString &lst, QVariantList &points, bool absCoords, double heightWu, bool closePath);
    QString fetchDescr(QXmlStreamReader &reader, QXmlStreamReader::TokenType &token, bool &currentTokenProcessed);
    QPointF applyGroupTransform(float x, float y) const;

private:
    QFileSystemWatcher fileObserver_;
    QString source_;

    QStack<QPointF> groupTranslates_;
};
