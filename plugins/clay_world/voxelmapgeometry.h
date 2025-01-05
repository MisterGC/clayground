#pragma once

#include <QQuick3DGeometry>
#include <QColor>
#include <QVector>
#include <QDataStream>

class VoxelMapGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(VoxelMapGeometry)

    Q_PROPERTY(int width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(int depth READ depth WRITE setDepth NOTIFY depthChanged)
    Q_PROPERTY(float voxelSize READ voxelSize WRITE setVoxelSize NOTIFY voxelSizeChanged)
    Q_PROPERTY(QColor defaultColor READ defaultColor WRITE setDefaultColor NOTIFY defaultColorChanged)

public:
    explicit VoxelMapGeometry();

    // Dimensions
    int width() const { return m_width; }
    int height() const { return m_height; }
    int depth() const { return m_depth; }
    void setWidth(int w);
    void setHeight(int h);
    void setDepth(int d);

    // Voxel size
    float voxelSize() const { return m_voxelSize; }
    void setVoxelSize(float size);

    // Color at (x,y,z)
    QColor defaultColor() const { return m_defaultColor; }
    void setDefaultColor(const QColor &color);
    Q_INVOKABLE QColor voxel(int x, int y, int z) const;
    Q_INVOKABLE void setVoxel(int x, int y, int z, const QColor &color);

    // I/O
    Q_INVOKABLE bool saveToFile(const QString &path, bool binary = true);
    Q_INVOKABLE bool loadFromFile(const QString &path, bool binary = true);

    Q_INVOKABLE void fillSphere(int cx, int cy, int cz, int r, const QColor &color);

signals:
    void widthChanged();
    void heightChanged();
    void depthChanged();
    void voxelSizeChanged();
    void defaultColorChanged();

private:
    void updateGeometry();
    int indexOf(int x, int y, int z) const { return x + y*m_width + z*m_width*m_height; }

    int m_width = 0;
    int m_height = 0;
    int m_depth = 0;
    float m_voxelSize = 1.0f;
    QVector<QColor> m_voxels; // flat storage of all voxel colors
    QColor m_defaultColor = Qt::red;
};
