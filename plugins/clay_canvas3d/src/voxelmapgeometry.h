#pragma once

#include <QQuick3DGeometry>
#include <QColor>
#include <QVector>
#include <QSet>
#include <QElapsedTimer>
#include <QFutureWatcher>
#include <QVariantMap>
#include "voxelmapdata.h"
#include "voxelchunk.h"

class VoxelMapGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(VoxelMapGeometry)

    Q_PROPERTY(int voxelCountX READ voxelCountX WRITE setVoxelCountX NOTIFY voxelCountXChanged)
    Q_PROPERTY(int voxelCountY READ voxelCountY WRITE setVoxelCountY NOTIFY voxelCountYChanged)
    Q_PROPERTY(int voxelCountZ READ voxelCountZ WRITE setVoxelCountZ NOTIFY voxelCountZChanged)
    Q_PROPERTY(float voxelSize READ voxelSize WRITE setVoxelSize NOTIFY voxelSizeChanged)
    Q_PROPERTY(float spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)
    Q_PROPERTY(int chunkSize READ chunkSize WRITE setChunkSize NOTIFY chunkSizeChanged)
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
    int chunkSize() const { return m_chunkSize; }
    void setChunkSize(int size);
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
    void chunkSizeChanged();
    void vertexCountChanged();

private slots:
    void onMeshBatchFinished();

private:
    // Called whenever the voxel data changes; schedules chunk (re)meshing.
    void onDataChanged();
    void rebuildChunkGrid();
    void addChunksForRegion(const VoxelDirtyRegion &region);
    void maybeStartBatch();
    void startBatch();
    VoxelChunk::MeshInput buildChunkInput(int chunkId) const;
    void concatenateAndUpload();
    int chunkIndex(int cx, int cy, int cz) const { return cx + cy*m_chunksX + cz*m_chunksX*m_chunksY; }

    VoxelMapData m_data;
    int m_vertexCount = 0;

    // Chunk grid
    int m_chunkSize = 32;
    int m_chunksX = 0, m_chunksY = 0, m_chunksZ = 0;
    QVector<VoxelChunk::MeshResult> m_chunkCache;   // indexed by chunk id

    // Async meshing coordination (all touched on the main thread)
    QSet<int> m_pendingDirty;
    bool m_pendingFull = false;
    bool m_batchRunning = false;
    QFutureWatcher<VoxelChunk::MeshResult> m_watcher;
    QElapsedTimer m_batchTimer;
    int m_batchChunkCount = 0;
    bool m_batchWasFull = false;
};
