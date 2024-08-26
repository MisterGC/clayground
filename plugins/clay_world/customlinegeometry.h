#ifndef CUSTOMLINEGEOMETRY_H
#define CUSTOMLINEGEOMETRY_H

#include <QVector3D>
#include <QQuick3DGeometry>

class CustomLineGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(CustomLineGeometry)

public:
    CustomLineGeometry();

    Q_PROPERTY(QVector<QVector3D> vertices READ vertices WRITE setVertices NOTIFY verticesChanged)

    QVector<QVector3D> vertices() const;
    void setVertices(const QVector<QVector3D> &newVertices);

signals:
    void verticesChanged();

private:
    void updateData();
    QVector<QVector3D> m_vertices;
    QVector3D calculateExtents() const;
};

#endif // CUSTOMLINEGEOMETRY_H