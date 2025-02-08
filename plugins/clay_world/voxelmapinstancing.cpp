#include "voxelmapinstancing.h"
#include <QMatrix4x4>
#include <QVector3D>
#include <QRandomGenerator>
#include <random>
#include <QtMath>
#include <QVariantMap>
#include <QVariantList>

VoxelMapInstancing::VoxelMapInstancing(QQuick3DObject *parent)
    : QQuick3DInstancing(parent)
{
}

void VoxelMapInstancing::setWidth(int w)
{
    if (m_width == w)
        return;
    m_width = w;
    m_voxels.resize(m_width * m_height * m_depth);
    m_voxels.fill(m_defaultColor);
    m_dirty = true;
    emit widthChanged();
    markDirty();
}

void VoxelMapInstancing::setHeight(int h)
{
    if (m_height == h)
        return;
    m_height = h;
    m_voxels.resize(m_width * m_height * m_depth);
    m_voxels.fill(m_defaultColor);
    m_dirty = true;
    emit heightChanged();
    markDirty();
}

void VoxelMapInstancing::setDepth(int d)
{
    if (m_depth == d)
        return;
    m_depth = d;
    m_voxels.resize(m_width * m_height * m_depth);
    m_voxels.fill(m_defaultColor);
    m_dirty = true;
    emit depthChanged();
    markDirty();
}

void VoxelMapInstancing::setVoxelSize(float size)
{
    if (qFuzzyCompare(m_voxelSize, size))
        return;
    m_voxelSize = size;
    m_dirty = true;
    emit voxelSizeChanged();
    markDirty();
}

void VoxelMapInstancing::setSpacing(float s)
{
    if (qFuzzyCompare(m_spacing, s))
        return;
    m_spacing = s;
    m_dirty = true;
    emit spacingChanged();
    markDirty();
}

void VoxelMapInstancing::setDefaultColor(const QColor &color)
{
    if (m_defaultColor == color)
        return;
    m_defaultColor = color;
    // (Optionally, you might refill m_voxels here.)
    m_dirty = true;
    emit defaultColorChanged();
    markDirty();
}

QColor VoxelMapInstancing::voxel(int x, int y, int z) const {
    if (x < 0 || x >= m_width || y < 0 || y >= m_height || z < 0 || z >= m_depth)
        return Qt::transparent;
    return m_voxels[indexOf(x, y, z)];
}

void VoxelMapInstancing::setVoxel(int x, int y, int z, const QColor &color) {
    if (x < 0 || x >= m_width || y < 0 || y >= m_height || z < 0 || z >= m_depth)
        return;
    int idx = indexOf(x, y, z);
    if (m_voxels[idx] == color)
        return;
    m_voxels[idx] = color;
    m_dirty = true;
    markDirty();
}

QVector<ColorProb> VoxelMapInstancing::prepareColorDistribution(const QVariantList &colorDistribution) {
    QVector<ColorProb> distribution;
    float totalWeight = 0.0f;
    for (const QVariant &item : colorDistribution) {
        QVariantMap entry = item.toMap();
        if (entry.contains("color") && entry.contains("weight")) {
            QColor color(entry["color"].toString());
            float weight = entry["weight"].toFloat();
            if (weight > 0.0f) {
                totalWeight += weight;
                distribution.append({color, weight});
            }
        }
    }
    if (!distribution.isEmpty()) {
        for (auto &item : distribution)
            item.probability /= totalWeight;
    }
    return distribution;
}

QColor VoxelMapInstancing::getRandomColor(const QVector<ColorProb> &distribution) {
    float randVal = QRandomGenerator::global()->generateDouble();
    float cumulative = 0.0f;
    QColor selected = distribution[0].color;
    for (const auto &item : distribution) {
        cumulative += item.probability;
        if (randVal <= cumulative) {
            selected = item.color;
            break;
        }
    }
    return selected;
}

float VoxelMapInstancing::applyNoise(float value, float noiseFactor) {
    if (noiseFactor <= 0.0f) return value;

    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-noiseFactor, noiseFactor);

    return value * (1.0f + dis(gen));
}

void VoxelMapInstancing::fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor) {
    if (r <= 0 || colorDistribution.isEmpty())
        return;
    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty())
        return;
    float maxRadius = r * (1.0f + noiseFactor);
    float baseR2 = (r - 0.5f) * (r - 0.5f);
    int minX = qMax(0, cx - int(maxRadius));
    int maxX = qMin(m_width - 1, cx + int(maxRadius));
    int minY = qMax(0, cy - int(maxRadius));
    int maxY = qMin(m_height - 1, cy + int(maxRadius));
    int minZ = qMax(0, cz - int(maxRadius));
    int maxZ = qMin(m_depth - 1, cz + int(maxRadius));

    for (int z = minZ; z <= maxZ; ++z) {
        for (int y = minY; y <= maxY; ++y) {
            for (int x = minX; x <= maxX; ++x) {
                float dx = x - cx;
                float dy = y - cy;
                float dz = z - cz;
                float dist2 = dx*dx + dy*dy + dz*dz;
                float currentR2 = applyNoise(baseR2, noiseFactor);
                if (dist2 <= currentR2)
                    m_voxels[indexOf(x,y,z)] = getRandomColor(distribution);
            }
        }
    }
    m_dirty = true;
    markDirty();
}

void VoxelMapInstancing::fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor) {
    if (r <= 0 || height <= 0 || colorDistribution.isEmpty())
        return;
    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty())
        return;
    float maxRadius = r * (1.0f + noiseFactor);
    float baseR2 = (r - 0.5f) * (r - 0.5f);
    int minX = qMax(0, cx - int(maxRadius));
    int maxX = qMin(m_width - 1, cx + int(maxRadius));
    int minY = qMax(0, cy);
    int maxY = qMin(m_height - 1, cy + height);
    int minZ = qMax(0, cz - int(maxRadius));
    int maxZ = qMin(m_depth - 1, cz + int(maxRadius));

    for (int y = minY; y <= maxY; ++y) {
        float currentR2 = applyNoise(baseR2, noiseFactor);
        for (int z = minZ; z <= maxZ; ++z) {
            for (int x = minX; x <= maxX; ++x) {
                float dx = x - cx;
                float dz = z - cz;
                if (dx*dx + dz*dz <= currentR2)
                    m_voxels[indexOf(x,y,z)] = getRandomColor(distribution);
            }
        }
    }
    m_dirty = true;
    markDirty();
}

void VoxelMapInstancing::fillBox(int cx, int cy, int cz, int boxWidth, int boxHeight, int boxDepth, const QVariantList &colorDistribution, float noiseFactor) {
    if (boxWidth <= 0 || boxHeight <= 0 || boxDepth <= 0 || colorDistribution.isEmpty())
        return;
    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty())
        return;
    float halfWidth = boxWidth / 2.0f;
    float halfHeight = boxHeight / 2.0f;
    float halfDepth = boxDepth / 2.0f;
    int minX = qMax(0, int(cx - halfWidth));
    int maxX = qMin(m_width - 1, int(cx + halfWidth));
    int minY = qMax(0, int(cy - halfHeight));
    int maxY = qMin(m_height - 1, int(cy + halfHeight));
    int minZ = qMax(0, int(cz - halfDepth));
    int maxZ = qMin(m_depth - 1, int(cz + halfDepth));

    for (int z = minZ; z <= maxZ; ++z) {
        for (int y = minY; y <= maxY; ++y) {
            for (int x = minX; x <= maxX; ++x) {
                if (noiseFactor > 0.0f) {
                    float dx = (x - cx) / halfWidth;
                    float dy = (y - cy) / halfHeight;
                    float dz = (z - cz) / halfDepth;
                    if (qAbs(dx) > (1.0f + applyNoise(0.0f, noiseFactor)) ||
                        qAbs(dy) > (1.0f + applyNoise(0.0f, noiseFactor)) ||
                        qAbs(dz) > (1.0f + applyNoise(0.0f, noiseFactor)))
                        continue;
                }
                m_voxels[indexOf(x,y,z)] = getRandomColor(distribution);
            }
        }
    }
    m_dirty = true;
    markDirty();
}

QByteArray VoxelMapInstancing::getInstanceBuffer(int *instanceCount) {
    if (m_dirty)
        updateInstanceData();
    int count = 0;
    for (const QColor &c : m_voxels) {
        if (c.alpha() != 0)
            ++count;
    }
    *instanceCount = count;
    return m_instanceData;
}

void VoxelMapInstancing::updateInstanceData() {
    m_instanceData.clear();

    // Calculate overall grid dimensions (same as VoxelMapGeometry)
    float totalWidth = m_width * (m_voxelSize + m_spacing) - m_spacing;
    float totalHeight = m_height * (m_voxelSize + m_spacing) - m_spacing;
    float totalDepth = m_depth * (m_voxelSize + m_spacing) - m_spacing;

    // Center the grid horizontally, keep bottom at y=0 (matching VoxelMapGeometry)
    float offsetX = -totalWidth / 2.0f;
    float offsetY = 0;  // Start at bottom
    float offsetZ = -totalDepth / 2.0f;

    // For each non-transparent voxel, compute its instance transformation and color
    for (int z = 0; z < m_depth; ++z) {
        for (int y = 0; y < m_height; ++y) {
            for (int x = 0; x < m_width; ++x) {
                QColor c = m_voxels[indexOf(x,y,z)];
                if (c.alpha() == 0)
                    continue;

                // Calculate position using same offset logic as VoxelMapGeometry
                float posX = offsetX + x * (m_voxelSize + m_spacing);
                float posY = offsetY + y * (m_voxelSize + m_spacing);
                float posZ = offsetZ + z * (m_voxelSize + m_spacing);

                QVector3D position(posX, posY, posZ);
                QVector3D scale(m_voxelSize, m_voxelSize, m_voxelSize);
                QQuaternion rotation;  // Identity rotation

                auto entry = calculateTableEntryFromQuaternion(
                    position,
                    scale,
                    rotation,
                    c
                );

                m_instanceData.append(reinterpret_cast<const char*>(&entry), sizeof(entry));
            }
        }
    }
    m_dirty = false;
}
