#pragma once

#include <QQuick3DGeometry>
#include <QVector3D>
#include <QColor>

class Line3dGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Line3dGeometry)

    Q_PROPERTY(QVector<QVector3D> vertices READ vertices WRITE setVertices NOTIFY verticesChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(float width READ width WRITE setWidth NOTIFY widthChanged)

public:
    Line3dGeometry();

    QVector<QVector3D> vertices() const;
    void setVertices(const QVector<QVector3D>& vertices);

    QColor color() const;
    void setColor(const QColor& color);

    float width() const;
    void setWidth(float width);

    void updateGeometry();

signals:
    void verticesChanged();
    void colorChanged();
    void widthChanged();

private:
    QVector3D calculateExtents() const;

private:
    QVector<QVector3D> m_vertices;
    QColor m_color;
    float m_width;
};
