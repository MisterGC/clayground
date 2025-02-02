#pragma once

#include <QQuick3DInstancing>
#include <QColor>
#include <QVector>

// Helper struct used for probabilistic color selection.
struct ColorProb {
    QColor color;
    float probability;
};

class VoxelMapInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_NAMED_ELEMENT(VoxelMapInstancing)
    Q_PROPERTY(int width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(int depth READ depth WRITE setDepth NOTIFY depthChanged)
    Q_PROPERTY(float voxelSize READ voxelSize WRITE setVoxelSize NOTIFY voxelSizeChanged)
    Q_PROPERTY(float spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)
    Q_PROPERTY(QColor defaultColor READ defaultColor WRITE setDefaultColor NOTIFY defaultColorChanged)

public:
    explicit VoxelMapInstancing(QQuick3DObject *parent = nullptr);

    int width() const { return m_width; }
    void setWidth(int w);
    int height() const { return m_height; }
    void setHeight(int h);
    int depth() const { return m_depth; }
    void setDepth(int d);

    float voxelSize() const { return m_voxelSize; }
    void setVoxelSize(float size);
    float spacing() const { return m_spacing; }
    void setSpacing(float s);

    QColor defaultColor() const { return m_defaultColor; }
    void setDefaultColor(const QColor &color);

    Q_INVOKABLE QColor voxel(int x, int y, int z) const;
    Q_INVOKABLE void setVoxel(int x, int y, int z, const QColor &color);

    Q_INVOKABLE void fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    Q_INVOKABLE void fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor = 0.0f);
    Q_INVOKABLE void fillBox(int cx, int cy, int cz, int boxWidth, int boxHeight, int boxDepth, const QVariantList &colorDistribution, float noiseFactor = 0.0f);

signals:
    void widthChanged();
    void heightChanged();
    void depthChanged();
    void voxelSizeChanged();
    void spacingChanged();
    void defaultColorChanged();

protected:
    // Called by the renderer to obtain the instance buffer.
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    void updateInstanceData();
    int indexOf(int x, int y, int z) const { return x + y * m_width + z * m_width * m_height; }

    // Utility functions for color distribution and noise.
    QVector<ColorProb> prepareColorDistribution(const QVariantList &colorDistribution);
    QColor getRandomColor(const QVector<ColorProb> &distribution);
    float applyNoise(float value, float noiseFactor);

    int m_width = 0;
    int m_height = 0;
    int m_depth = 0;
    float m_voxelSize = 1.0f;
    float m_spacing = 0.0f;
    QColor m_defaultColor = Qt::red;
    QVector<QColor> m_voxels; // Flat storage of voxel colors.
    QByteArray m_instanceData;
    bool m_dirty = true;
};
