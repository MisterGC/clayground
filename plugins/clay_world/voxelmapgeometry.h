#pragma once

#include <QQuick3DGeometry>
#include <QColor>
#include <QVector>
#include <QDataStream>
#include <QVariantMap>
#include "voxelmapdata.h"

class VoxelMapGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(VoxelMapGeometry)

    Q_PROPERTY(int width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(int depth READ depth WRITE setDepth NOTIFY depthChanged)
    Q_PROPERTY(float voxelSize READ voxelSize WRITE setVoxelSize NOTIFY voxelSizeChanged)
    Q_PROPERTY(float spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)

public:
    explicit VoxelMapGeometry();

    // Forward property getters/setters to m_data
    int width() const;
    int height() const;
    int depth() const;
    void setWidth(int w);
    void setHeight(int h);
    void setDepth(int d);
    float voxelSize() const;
    void setVoxelSize(float size);
    float spacing() const;
    void setSpacing(float spacing);

    // Forward QML-invokable methods to m_data
    Q_INVOKABLE bool saveToFile(const QString &path, bool binary = true);
    Q_INVOKABLE bool loadFromFile(const QString &path, bool binary = true);
    Q_INVOKABLE QColor voxel(int x, int y, int z) const;
    Q_INVOKABLE void setVoxel(int x, int y, int z, const QColor &color);
    Q_INVOKABLE void fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    Q_INVOKABLE void fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    Q_INVOKABLE void fillBox(int cx, int cy, int cz, int width, int height, int depth, const QVariantList &colorDistribution, float noiseFactor = 0.0f);

signals:
    void widthChanged();
    void heightChanged();
    void depthChanged();
    void voxelSizeChanged();
    void spacingChanged();

private:
    void updateGeometry();
    bool isFaceVisible(int x, int y, int z, int faceIndex) const;
    VoxelMapData m_data;
};
