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

    Q_PROPERTY(QVector<QVector<QVector3D>> lines READ lines WRITE setLines NOTIFY linesChanged)

    QVector<QVector<QVector3D>> lines() const;
    void setLines(const QVector<QVector<QVector3D>> &newLines);

signals:
    void linesChanged();

private:
    void updateData();
    QVector<QVector<QVector3D>> m_lines;
    QVector3D calculateExtents() const;
};

#endif // CUSTOMLINEGEOMETRY_H