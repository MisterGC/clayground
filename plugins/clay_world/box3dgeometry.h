#ifndef BOX3DGEOMETRY_H
#define BOX3DGEOMETRY_H

#include <QQuick3DGeometry>
#include <QVector3D>

class Box3dGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Box3dGeometry)

    Q_PROPERTY(QVector3D size READ size WRITE setSize NOTIFY sizeChanged)

public:
    Box3dGeometry();

    QVector3D size() const;
    void setSize(const QVector3D &newSize);

signals:
    void sizeChanged();

private:
    void updateData();
    QVector3D m_size;
};

#endif // BOX3DGEOMETRY_H