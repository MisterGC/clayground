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
    Q_PROPERTY(int vertexCount READ vertexCount NOTIFY vertexCountChanged)
    Q_PROPERTY(bool useGreedyMeshing READ useGreedyMeshing WRITE setUseGreedyMeshing NOTIFY useGreedyMeshingChanged)

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
    int vertexCount() const { return m_vertexCount; }
    bool useGreedyMeshing() const { return m_useGreedyMeshing; }
    void setUseGreedyMeshing(bool enabled);

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
    void widthChanged();
    void heightChanged();
    void depthChanged();
    void voxelSizeChanged();
    void spacingChanged();
    void vertexCountChanged();
    void useGreedyMeshingChanged();

private:
    // Greedy meshing structures
    struct GreedyQuad {
        int x, y, z;  // Starting voxel position
        int width, height;  // Size in voxels (on the face's 2D plane)
        QColor color;
        int faceIndex;
    };
    
    void updateGeometry();
    void updateGeometryGreedy();   // Greedy meshing method
    void updateGeometryClassic();  // Original per-voxel face method
    bool isFaceVisible(int x, int y, int z, int faceIndex) const;
    QVector<GreedyQuad> generateGreedyQuads();
    VoxelMapData m_data;
    int m_vertexCount = 0;
    bool m_useGreedyMeshing = true;  // Default to true for efficiency
};
