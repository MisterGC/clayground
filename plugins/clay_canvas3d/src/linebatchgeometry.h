#ifndef LINEBATCHGEOMETRY_H
#define LINEBATCHGEOMETRY_H

#include <QVector3D>
#include <QQuick3DGeometry>

class LineBatchGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LineBatchGeometry)

    Q_PROPERTY(QVector3D boundsMin READ boundsMin WRITE setBoundsMin NOTIFY boundsMinChanged)
    Q_PROPERTY(QVector3D boundsMax READ boundsMax WRITE setBoundsMax NOTIFY boundsMaxChanged)

public:
    LineBatchGeometry();

    QVector3D boundsMin() const;
    void setBoundsMin(const QVector3D &v);

    QVector3D boundsMax() const;
    void setBoundsMax(const QVector3D &v);

signals:
    void boundsMinChanged();
    void boundsMaxChanged();

private:
    void rebuild();

    QVector3D m_boundsMin;
    QVector3D m_boundsMax;
};

#endif // LINEBATCHGEOMETRY_H
