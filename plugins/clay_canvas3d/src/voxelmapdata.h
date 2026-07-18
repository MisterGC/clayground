#pragma once

#include <QObject>
#include <QColor>
#include <QVector>
#include <QHash>
#include <QVariantList>
#include <functional>

struct ColorProb {
    QColor color;
    float probability;
};

// Region of the volume that changed since the last takeDirtyRegion() call.
// Used by the geometry backend to remesh only the affected chunks.
struct VoxelDirtyRegion {
    bool full = false;   // whole volume must be reconsidered (resize / load / first build)
    bool empty = true;   // nothing changed
    int minX = 0, minY = 0, minZ = 0;
    int maxX = 0, maxY = 0, maxZ = 0;
};

class VoxelMapData : public QObject
{
    Q_OBJECT

public:
    explicit VoxelMapData(QObject *parent = nullptr);

    // Dimensions (in voxel counts, not world units)
    int voxelCountX() const { return m_voxelCountX; }
    int voxelCountY() const { return m_voxelCountY; }
    int voxelCountZ() const { return m_voxelCountZ; }
    void setVoxelCountX(int count);
    void setVoxelCountY(int count);
    void setVoxelCountZ(int count);

    // Voxel properties
    float voxelSize() const { return m_voxelSize; }
    void setVoxelSize(float size);
    float spacing() const { return m_spacing; }
    void setSpacing(float spacing);

    // Voxel access
    QColor voxel(int x, int y, int z) const;
    void setVoxel(int x, int y, int z, const QColor &color);

    // Number of non-transparent voxels, maintained incrementally.
    int solidCount() const { return m_solidCount; }

    // Approximate bytes used by the voxel index store (excluding the palette).
    qsizetype storageBytes() const;
    int paletteSize() const { return m_palette.size(); }

    // Shape filling
    void fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    void fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    void fillBox(int cx, int cy, int cz, int width, int height, int depth, const QVariantList &colorDistribution, float noiseFactor = 0.0f);

    // I/O
    bool saveToFile(const QString &path);
    bool loadFromFile(const QString &path);

    // Change notification
    void setOnDataChanged(std::function<void()> callback) { m_onDataChanged = callback; }

    // Consume the accumulated dirty region and reset it to empty.
    VoxelDirtyRegion takeDirtyRegion();

    Q_INVOKABLE void commit();

signals:
    void voxelCountXChanged();
    void voxelCountYChanged();
    void voxelCountZChanged();
    void voxelSizeChanged();
    void spacingChanged();
    void autoCommitChanged();

protected:
    int indexOf(int x, int y, int z) const { return x + y*m_voxelCountX + z*m_voxelCountX*m_voxelCountY; }
    void notifyDataChanged();

private:
    static QVector<ColorProb> prepareColorDistribution(const QVariantList &colorDistribution);
    static QColor getRandomColor(const QVector<ColorProb> &distribution);
    static float applyNoise(float value, float noiseFactor);

    // Palette-index storage helpers.
    int paletteIndexAt(int flat) const { return m_use16 ? int(m_indices16[flat]) : int(m_indices8[flat]); }
    void setPaletteIndexAt(int flat, int idx);
    int indexForColor(const QColor &color);   // grows palette / upgrades width as needed
    void upgradeTo16();
    void applyResize(int newX, int newY, int newZ);   // preserves overlapping content
    void allocateIndices(qsizetype count);            // zero-filled (all empty)
    // Fast path used by fill*(): writes without per-voxel notification.
    void setVoxelRaw(int x, int y, int z, const QColor &color);
    void markDirtyVoxel(int x, int y, int z);
    void markDirtyFull();

    int m_voxelCountX = 0;
    int m_voxelCountY = 0;
    int m_voxelCountZ = 0;
    float m_voxelSize = 1.0f;
    float m_spacing = 0.0f;

    // Dense palette-index store. Index 0 is reserved for empty (transparent).
    // 8-bit until more than 255 distinct colors are used, then upgraded to 16-bit.
    bool m_use16 = false;
    QVector<quint8> m_indices8;
    QVector<quint16> m_indices16;
    QVector<QColor> m_palette;          // m_palette[0] == transparent
    QHash<QRgb, int> m_colorToIndex;    // reverse lookup for solid colors

    int m_solidCount = 0;
    VoxelDirtyRegion m_dirty;

    std::function<void()> m_onDataChanged;
};
