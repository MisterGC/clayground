#ifndef LINEBATCHINSTANCING_H
#define LINEBATCHINSTANCING_H

#include <QQuick3DInstancing>
#include <QVector3D>
#include <QVector4D>
#include <QVariantList>
#include <QByteArray>
#include <QList>

class LineBatchInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LineBatchInstancing)

    Q_PROPERTY(QVariantList lines READ lines WRITE setLines NOTIFY linesChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QVector3D boundsMin READ boundsMin NOTIFY boundsChanged)
    Q_PROPERTY(QVector3D boundsMax READ boundsMax NOTIFY boundsChanged)

public:
    explicit LineBatchInstancing(QQuick3DObject *parent = nullptr);

    QVariantList lines() const;
    void setLines(const QVariantList &lines);

    int count() const;
    QVector3D boundsMin() const;
    QVector3D boundsMax() const;

    // Fast bulk path for generators. See LineBatch3D::setBulk documentation.
    Q_INVOKABLE void setBulk(const QByteArray &positions,
                             const QByteArray &startIndices,
                             const QByteArray &colors,
                             const QByteArray &widths);

    // Patches only the given line's instance-table region, then re-uploads.
    Q_INVOKABLE void updateLinePoints(int lineIndex, const QVariantList &points);

signals:
    void linesChanged();
    void countChanged();
    void boundsChanged();

protected:
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    struct Line {
        QList<QVector3D> points;
        QVector4D color;
        float width = 1.0f;
        int styleId = 0;
        int instanceStart = 0; // first instance (segment) index of this line
        int instanceCount = 0; // number of segments in this line
    };

    void rebuild();
    void writeLineEntries(char *dst, const Line &line) const;
    void updateBounds();

    QList<Line> m_lines;
    QByteArray m_data;
    int m_instanceCount = 0;
    QVector3D m_boundsMin;
    QVector3D m_boundsMax;
    bool m_dirty = true;
};

#endif // LINEBATCHINSTANCING_H
