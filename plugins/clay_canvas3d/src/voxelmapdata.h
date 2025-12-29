#pragma once

#include <QObject>
#include <QColor>
#include <QVector>
#include <QVariantList>
#include <functional>

struct ColorProb {
    QColor color;
    float probability;
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
    const QVector<QColor>& voxels() const { return m_voxels; }

    // Shape filling
    void fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    void fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    void fillBox(int cx, int cy, int cz, int width, int height, int depth, const QVariantList &colorDistribution, float noiseFactor = 0.0f);

    // I/O
    bool saveToFile(const QString &path);
    bool loadFromFile(const QString &path);

    // Change notification
    void setOnDataChanged(std::function<void()> callback) { m_onDataChanged = callback; }

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

    int m_voxelCountX = 0;
    int m_voxelCountY = 0;
    int m_voxelCountZ = 0;
    float m_voxelSize = 1.0f;
    float m_spacing = 0.0f;
    QVector<QColor> m_voxels;
    std::function<void()> m_onDataChanged;
};
