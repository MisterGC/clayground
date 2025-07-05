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

    // Dimensions
    int width() const { return m_width; }
    int height() const { return m_height; }
    int depth() const { return m_depth; }
    void setWidth(int w);
    void setHeight(int h);
    void setDepth(int d);

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
    void widthChanged();
    void heightChanged();
    void depthChanged();
    void voxelSizeChanged();
    void spacingChanged();
    void autoCommitChanged();

protected:
    int indexOf(int x, int y, int z) const { return x + y*m_width + z*m_width*m_height; }
    void notifyDataChanged();

private:
    static QVector<ColorProb> prepareColorDistribution(const QVariantList &colorDistribution);
    static QColor getRandomColor(const QVector<ColorProb> &distribution);
    static float applyNoise(float value, float noiseFactor);

    int m_width = 0;
    int m_height = 0;
    int m_depth = 0;
    float m_voxelSize = 1.0f;
    float m_spacing = 0.0f;
    QVector<QColor> m_voxels;
    std::function<void()> m_onDataChanged;
};
