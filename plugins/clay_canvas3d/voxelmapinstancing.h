#pragma once

#include <QQuick3DInstancing>
#include <QColor>
#include <QVector>
#include "voxelmapdata.h"

// Helper struct used for probabilistic color selection.

class VoxelMapInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_NAMED_ELEMENT(VoxelMapInstancing)
    Q_PROPERTY(int width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(int depth READ depth WRITE setDepth NOTIFY depthChanged)
    Q_PROPERTY(float voxelSize READ voxelSize WRITE setVoxelSize NOTIFY voxelSizeChanged)
    Q_PROPERTY(float spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)

public:
    explicit VoxelMapInstancing(QQuick3DObject *parent = nullptr);

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

protected:
    // Called by the renderer to obtain the instance buffer.
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    void updateInstanceData();
    VoxelMapData m_data;
    QByteArray m_instanceData;
    bool m_dirty = true;

    struct ColorProb {
        QColor color;
        float probability;
    };
    // Utility functions for color distribution and noise.
    QVector<ColorProb> prepareColorDistribution(const QVariantList &colorDistribution);
    QColor getRandomColor(const QVector<ColorProb> &distribution);
    float applyNoise(float value, float noiseFactor);
};
