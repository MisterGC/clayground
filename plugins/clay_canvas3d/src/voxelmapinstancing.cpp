#include "voxelmapinstancing.h"
#include <QMatrix4x4>
#include <QVector3D>
#include <QRandomGenerator>
#include <random>
#include <QtMath>
#include <QVariantMap>
#include <QVariantList>
#include <QQuaternion>

VoxelMapInstancing::VoxelMapInstancing(QQuick3DObject *parent)
    : QQuick3DInstancing(parent)
{
    // Set up a callback from m_data to mark the instancing as dirty.
    m_data.setOnDataChanged([this]() {
        m_dirty = true;
        markDirty();
    });

    // Connect property change signals from m_data.
    connect(&m_data, &VoxelMapData::voxelCountXChanged, this, &VoxelMapInstancing::voxelCountXChanged);
    connect(&m_data, &VoxelMapData::voxelCountYChanged, this, &VoxelMapInstancing::voxelCountYChanged);
    connect(&m_data, &VoxelMapData::voxelCountZChanged, this, &VoxelMapInstancing::voxelCountZChanged);
    connect(&m_data, &VoxelMapData::voxelSizeChanged, this, &VoxelMapInstancing::voxelSizeChanged);
    connect(&m_data, &VoxelMapData::spacingChanged, this, &VoxelMapInstancing::spacingChanged);
}

// ==========================================
// Delegated Methods (for properties)
// ==========================================
int VoxelMapInstancing::voxelCountX() const {
    return m_data.voxelCountX();
}

int VoxelMapInstancing::voxelCountY() const {
    return m_data.voxelCountY();
}

int VoxelMapInstancing::voxelCountZ() const {
    return m_data.voxelCountZ();
}

void VoxelMapInstancing::setVoxelCountX(int count) {
    m_data.setVoxelCountX(count);
}

void VoxelMapInstancing::setVoxelCountY(int count) {
    m_data.setVoxelCountY(count);
}

void VoxelMapInstancing::setVoxelCountZ(int count) {
    m_data.setVoxelCountZ(count);
}

float VoxelMapInstancing::voxelSize() const {
    return m_data.voxelSize();
}

void VoxelMapInstancing::setVoxelSize(float size) {
    m_data.setVoxelSize(size);
}

float VoxelMapInstancing::spacing() const {
    return m_data.spacing();
}

void VoxelMapInstancing::setSpacing(float spacing) {
    m_data.setSpacing(spacing);
}

// ==========================================
// Delegated Methods (for QML-invokable functions)
// ==========================================
bool VoxelMapInstancing::saveToFile(const QString &path)
{
    return m_data.saveToFile(path);
}

bool VoxelMapInstancing::loadFromFile(const QString &path)
{
    return m_data.loadFromFile(path);
}

QColor VoxelMapInstancing::voxel(int x, int y, int z) const {
    return m_data.voxel(x, y, z);
}

void VoxelMapInstancing::setVoxel(int x, int y, int z, const QColor &color) {
    m_data.setVoxel(x, y, z, color);
}

void VoxelMapInstancing::fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillSphere(cx, cy, cz, r, colorDistribution, noiseFactor);
}

void VoxelMapInstancing::fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillCylinder(cx, cy, cz, r, height, colorDistribution, noiseFactor);
}

void VoxelMapInstancing::fillBox(int cx, int cy, int cz, int width, int height, int depth, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillBox(cx, cy, cz, width, height, depth, colorDistribution, noiseFactor);
}

// ==========================================
// Instance Buffer Updates (geometry-specific)
// ==========================================
QByteArray VoxelMapInstancing::getInstanceBuffer(int *instanceCount)
{
    if (m_dirty)
        updateInstanceData();

    // Count non-transparent voxels from m_data.
    int count = 0;
    for (int z = 0; z < m_data.voxelCountZ(); ++z) {
        for (int y = 0; y < m_data.voxelCountY(); ++y) {
            for (int x = 0; x < m_data.voxelCountX(); ++x) {
                if (m_data.voxel(x, y, z).alpha() != 0)
                    ++count;
            }
        }
    }
    *instanceCount = count;
    return m_instanceData;
}

void VoxelMapInstancing::updateInstanceData()
{
    m_instanceData.clear();

    // Calculate overall grid dimensions based on m_data properties.
    float totalWidth  = m_data.voxelCountX()  * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();
    float totalHeight = m_data.voxelCountY() * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();
    float totalDepth  = m_data.voxelCountZ()  * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();

    // Center the grid horizontally; keep the bottom at y = 0.
    float offsetX = -totalWidth / 2.0f;
    float offsetY = 0.0f;
    float offsetZ = -totalDepth / 2.0f;

    // For each non-transparent voxel, generate its instance (for transformation and color).
    for (int z = 0; z < m_data.voxelCountZ(); ++z) {
        for (int y = 0; y < m_data.voxelCountY(); ++y) {
            for (int x = 0; x < m_data.voxelCountX(); ++x) {
                QColor c = m_data.voxel(x, y, z);
                if (c.alpha() == 0)
                    continue;

                float posX = offsetX + x * (m_data.voxelSize() + m_data.spacing()) + m_data.voxelSize() / 2;
                float posY = offsetY + y * (m_data.voxelSize() + m_data.spacing()) + m_data.voxelSize() / 2;
                float posZ = offsetZ + z * (m_data.voxelSize() + m_data.spacing()) + m_data.voxelSize() / 2;

                QVector3D position(posX, posY, posZ);
                //QVector3D scale(m_data.voxelSize(), m_data.voxelSize(), m_data.voxelSize());
                QVector3D scale(1.0, 1.0, 1.0);
                QQuaternion rotation; // Identity rotation

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

// ==========================================
// Utility Functions (unchanged)
// ==========================================
QVector<VoxelMapInstancing::ColorProb> VoxelMapInstancing::prepareColorDistribution(const QVariantList &colorDistribution) {
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

void VoxelMapInstancing::commit()
{
    m_data.commit();
}
