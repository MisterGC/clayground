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

    Q_PROPERTY(int voxelCountX READ voxelCountX WRITE setVoxelCountX NOTIFY voxelCountXChanged)
    Q_PROPERTY(int voxelCountY READ voxelCountY WRITE setVoxelCountY NOTIFY voxelCountYChanged)
    Q_PROPERTY(int voxelCountZ READ voxelCountZ WRITE setVoxelCountZ NOTIFY voxelCountZChanged)
    Q_PROPERTY(float voxelSize READ voxelSize WRITE setVoxelSize NOTIFY voxelSizeChanged)
    Q_PROPERTY(float spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)
    Q_PROPERTY(int vertexCount READ vertexCount NOTIFY vertexCountChanged)

public:
    explicit VoxelMapGeometry();

    // Forward property getters/setters to m_data
    int voxelCountX() const;
    int voxelCountY() const;
    int voxelCountZ() const;
    void setVoxelCountX(int count);
    void setVoxelCountY(int count);
    void setVoxelCountZ(int count);
    float voxelSize() const;
    void setVoxelSize(float size);
    float spacing() const;
    void setSpacing(float spacing);
    int vertexCount() const { return m_vertexCount; }

    // Forward QML-invokable methods to m_data
    Q_INVOKABLE bool saveToFile(const QString &path);
    Q_INVOKABLE bool loadFromFile(const QString &path);
    Q_INVOKABLE QColor voxel(int x, int y, int z) const;
    Q_INVOKABLE void setVoxel(int x, int y, int z, const QColor &color);
    Q_INVOKABLE void fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    Q_INVOKABLE void fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    Q_INVOKABLE void fillBox(int cx, int cy, int cz, int width, int height, int depth, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    Q_INVOKABLE void commit();

signals:
    void voxelCountXChanged();
    void voxelCountYChanged();
    void voxelCountZChanged();
    void voxelSizeChanged();
    void spacingChanged();
    void vertexCountChanged();

private:
    // Greedy meshing structures
    struct GreedyQuad {
        int x, y, z;  // Starting voxel position
        int width, height;  // Size in voxels (on the face's 2D plane)
        QColor color;
        int faceIndex;
    };
    
    void updateGeometry();
    bool isFaceVisible(int x, int y, int z, int faceIndex) const;
    QVector<GreedyQuad> generateGreedyQuads();
    VoxelMapData m_data;
    int m_vertexCount = 0;
};
