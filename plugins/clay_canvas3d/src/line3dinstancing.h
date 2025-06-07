#pragma once

#include <QQuick3DInstancing>
#include <QVector3D>
#include <QColor>

class LineInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LineInstancing)

    Q_PROPERTY(QList<QVector3D> positions READ positions WRITE setPositions NOTIFY positionsChanged)
    Q_PROPERTY(float width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)

public:
    explicit LineInstancing(QQuick3DObject *parent = nullptr);

    QList<QVector3D> positions() const;
    void setPositions(const QList<QVector3D> &positions);

    float width() const;
    void setWidth(float width);

    QColor color() const;
    void setColor(const QColor &color);

signals:
    void positionsChanged();
    void widthChanged();
    void colorChanged();

protected:
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    QList<QVector3D> m_positions;
    float m_width;
    QColor m_color;
    QByteArray m_instanceData;
    bool m_dirty;

    void updateInstanceData();
};
