#include "voxelmapdata.h"
#include <QFile>
#include <QTextStream>
#include <QDataStream>
#include <QDebug>
#include <random>
#include <QtMath>

// Helper functions for file I/O
static QString colorToString(const QColor &c)
{
    return QString("%1,%2,%3,%4").arg(c.red()).arg(c.green()).arg(c.blue()).arg(c.alpha());
}

static QColor stringToColor(const QString &str)
{
    auto parts = str.split(",");
    if (parts.size() < 4) return Qt::transparent;
    return QColor(parts[0].toInt(), parts[1].toInt(), parts[2].toInt(), parts[3].toInt());
}

VoxelMapData::VoxelMapData(QObject *parent)
    : QObject(parent)
{
}

void VoxelMapData::setVoxelCountX(int count)
{
    if (m_voxelCountX == count)
        return;
    m_voxelCountX = count;
    m_voxels.resize(m_voxelCountX * m_voxelCountY * m_voxelCountZ);
    m_voxels.fill(Qt::transparent);
    emit voxelCountXChanged();
    notifyDataChanged();
}

void VoxelMapData::setVoxelCountY(int count)
{
    if (m_voxelCountY == count)
        return;
    m_voxelCountY = count;
    m_voxels.resize(m_voxelCountX * m_voxelCountY * m_voxelCountZ);
    m_voxels.fill(Qt::transparent);
    emit voxelCountYChanged();
    notifyDataChanged();
}

void VoxelMapData::setVoxelCountZ(int count)
{
    if (m_voxelCountZ == count)
        return;
    m_voxelCountZ = count;
    m_voxels.resize(m_voxelCountX * m_voxelCountY * m_voxelCountZ);
    m_voxels.fill(Qt::transparent);
    emit voxelCountZChanged();
    notifyDataChanged();
}

void VoxelMapData::setVoxelSize(float size)
{
    if (qFuzzyCompare(m_voxelSize, size))
        return;
    m_voxelSize = size;
    emit voxelSizeChanged();
    notifyDataChanged();
}

void VoxelMapData::setSpacing(float spacing)
{
    if (qFuzzyCompare(m_spacing, spacing))
        return;
    m_spacing = spacing;
    emit spacingChanged();
    notifyDataChanged();
}

QColor VoxelMapData::voxel(int x, int y, int z) const
{
    if (x < 0 || x >= m_voxelCountX || y < 0 || y >= m_voxelCountY || z < 0 || z >= m_voxelCountZ)
        return Qt::transparent;
    return m_voxels[indexOf(x, y, z)];
}

void VoxelMapData::setVoxel(int x, int y, int z, const QColor &color)
{
    if (x < 0 || x >= m_voxelCountX || y < 0 || y >= m_voxelCountY || z < 0 || z >= m_voxelCountZ)
        return;
    int idx = indexOf(x, y, z);
    if (m_voxels[idx] == color)
        return;
    m_voxels[idx] = color;
    notifyDataChanged();
}

QVector<ColorProb> VoxelMapData::prepareColorDistribution(const QVariantList &colorDistribution)
{
    QVector<ColorProb> distribution;
    float totalWeight = 0.0f;

    for (const QVariant &item : colorDistribution) {
        QVariantMap entry = item.toMap();
        if (entry.contains("color") && entry.contains("weight")) {
            QColor color = QColor(entry["color"].toString());
            float weight = entry["weight"].toFloat();
            if (weight > 0.0f) {
                totalWeight += weight;
                distribution.append({color, weight});
            }
        }
    }

    if (!distribution.isEmpty()) {
        for (auto &item : distribution) {
            item.probability /= totalWeight;
        }
    }

    return distribution;
}

QColor VoxelMapData::getRandomColor(const QVector<ColorProb> &distribution)
{
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_real_distribution<float> dis(0.0f, 1.0f);

    float rand = dis(gen);
    float cumulative = 0.0f;
    QColor selectedColor = distribution[0].color; // fallback

    for (const auto &item : distribution) {
        cumulative += item.probability;
        if (rand <= cumulative) {
            selectedColor = item.color;
            break;
        }
    }

    return selectedColor;
}

float VoxelMapData::applyNoise(float value, float noiseFactor)
{
    if (noiseFactor <= 0.0f) return value;

    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-noiseFactor, noiseFactor);

    return value * (1.0f + dis(gen));
}

void VoxelMapData::fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor)
{
    // Validate inputs
    if (r <= 0.0f || colorDistribution.isEmpty()) return;
    if (cx < -r || cy < -r || cz < -r) return;
    if (cx >= voxelCountX() + r || cy >= voxelCountY() + r || cz >= voxelCountZ() + r) return;

    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty()) return;

    float maxRadius = r * (1.0f + noiseFactor);
    float baseR2 = (r - 0.5f) * (r - 0.5f);

    int minX = qBound(0, int(cx - maxRadius), voxelCountX() - 1);
    int maxX = qBound(0, int(cx + maxRadius), voxelCountX() - 1);
    int minY = qBound(0, int(cy - maxRadius), voxelCountY() - 1);
    int maxY = qBound(0, int(cy + maxRadius), voxelCountY() - 1);
    int minZ = qBound(0, int(cz - maxRadius), voxelCountZ() - 1);
    int maxZ = qBound(0, int(cz + maxRadius), voxelCountZ() - 1);

    if (minX > maxX || minY > maxY || minZ > maxZ) return;

    for (int z = minZ; z <= maxZ; ++z) {
        for (int y = minY; y <= maxY; ++y) {
            for (int x = minX; x <= maxX; ++x) {
                float dx = float(x - cx);
                float dy = float(y - cy);
                float dz = float(z - cz);
                float distanceSquared = dx*dx + dy*dy + dz*dz;
                float currentR2 = applyNoise(baseR2, noiseFactor);
                if (distanceSquared <= currentR2) {
                    m_voxels[indexOf(x,y,z)] = getRandomColor(distribution);
                }
            }
        }
    }
}

void VoxelMapData::fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor)
{
    // Validate inputs
    if (r <= 0.0f || height <= 0 || colorDistribution.isEmpty()) return;
    if (cx < -r || cy < 0 || cz < -r) return;
    if (cx >= voxelCountX() + r || cy >= voxelCountY() + height || cz >= voxelCountZ() + r) return;

    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty()) return;

    float maxRadius = r * (1.0f + noiseFactor);
    float baseR2 = (r - 0.5f) * (r - 0.5f);

    int minX = qBound(0, int(cx - maxRadius), voxelCountX() - 1);
    int maxX = qBound(0, int(cx + maxRadius), voxelCountX() - 1);
    int minY = qBound(0, int(cy), voxelCountY() - 1);
    int maxY = qBound(0, int(cy + height), voxelCountY() - 1);
    int minZ = qBound(0, int(cz - maxRadius), voxelCountZ() - 1);
    int maxZ = qBound(0, int(cz + maxRadius), voxelCountZ() - 1);

    if (minX > maxX || minY > maxY || minZ > maxZ) return;

    for (int y = minY; y <= maxY; ++y) {
        float currentR2 = applyNoise(baseR2, noiseFactor);
        for (int z = minZ; z <= maxZ; ++z) {
            for (int x = minX; x <= maxX; ++x) {
                float dx = float(x - cx);
                float dz = float(z - cz);
                if (dx*dx + dz*dz <= currentR2) {
                    m_voxels[indexOf(x,y,z)] = getRandomColor(distribution);
                }
            }
        }
    }
}

void VoxelMapData::fillBox(int minX, int minY, int minZ, int boxWidth, int boxHeight, int boxDepth, const QVariantList &colorDistribution, float noiseFactor)
{
    // Validate inputs
    if (boxWidth <= 0 || boxHeight <= 0 || boxDepth <= 0 || colorDistribution.isEmpty()) return;

    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty()) return;

    // Calculate bounds directly from min position
    int maxX = qBound(0, minX + boxWidth - 1, voxelCountX() - 1);
    int maxY = qBound(0, minY + boxHeight - 1, voxelCountY() - 1);
    int maxZ = qBound(0, minZ + boxDepth - 1, voxelCountZ() - 1);
    minX = qBound(0, minX, voxelCountX() - 1);
    minY = qBound(0, minY, voxelCountY() - 1);
    minZ = qBound(0, minZ, voxelCountZ() - 1);

    if (minX > maxX || minY > maxY || minZ > maxZ) return;

    for (int z = minZ; z <= maxZ; ++z) {
        for (int y = minY; y <= maxY; ++y) {
            for (int x = minX; x <= maxX; ++x) {
                if (noiseFactor > 0.0f) {
                    float dx = float(x - minX) / boxWidth;
                    float dy = float(y - minY) / boxHeight;
                    float dz = float(z - minZ) / boxDepth;

                    if (dx > (1.0f + applyNoise(0.0f, noiseFactor)) ||
                        dy > (1.0f + applyNoise(0.0f, noiseFactor)) ||
                        dz > (1.0f + applyNoise(0.0f, noiseFactor))) {
                        continue;
                    }
                }

                m_voxels[indexOf(x,y,z)] = getRandomColor(distribution);
            }
        }
    }
}

bool VoxelMapData::saveToFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to open file for writing:" << path;
        return false;
    }

    QTextStream out(&file);

    // Write header with metadata
    out << "# Clayground Voxel Map\n";
    out << "# One line per voxel\n";
    out << "# X Y Z RRGGBB\n";
    out << "# Note: In this format, Y is depth and Z is height\n";
    out << "# Dimensions: " << m_voxelCountX << " " << m_voxelCountZ << " " << m_voxelCountY << "\n";
    out << "# VoxelSize: " << m_voxelSize << "\n";
    out << "# Spacing: " << m_spacing << "\n";

    // Write voxel data - one line per voxel
    // In text format: X=width, Y=depth, Z=height
    // In our data: X=voxelCountX, Y=voxelCountY, Z=voxelCountZ
    for (int z = 0; z < m_voxelCountZ; z++) {
        for (int y = 0; y < m_voxelCountY; y++) {
            for (int x = 0; x < m_voxelCountX; x++) {
                QColor color = m_voxels[indexOf(x, y, z)];

                // Only write non-transparent voxels
                if (color.alpha() > 0) {
                    // Write as "X Y Z RRGGBB" format
                    // Map our (x,y,z) to text format (x,z,y)
                    out << x << " " << (m_voxelCountZ - z) << " " << y << " "
                        << QString("%1%2%3")
                           .arg(color.red(), 2, 16, QChar('0'))
                           .arg(color.green(), 2, 16, QChar('0'))
                           .arg(color.blue(), 2, 16, QChar('0'))
                        << "\n";
                }
            }
        }
    }

    file.close();
    return true;
}

bool VoxelMapData::loadFromFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to open file for reading:" << path;
        return false;
    }

    QTextStream in(&file);

    // Default dimensions in case they're not in the file
    int newVoxelCountX = m_voxelCountX;
    int newVoxelCountY = m_voxelCountY;
    int newVoxelCountZ = m_voxelCountZ;
    float newVoxelSize = m_voxelSize;
    float newSpacing = m_spacing;

    // First pass: read metadata from comments and find max dimensions
    QString line;
    while (!in.atEnd()) {
        line = in.readLine().trimmed();

        // Skip empty lines
        if (line.isEmpty()) continue;

        // Process metadata in comments
        if (line.startsWith("#")) {
            if (line.contains("Dimensions:")) {
                QStringList parts = line.split(" ");
                if (parts.size() >= 5) {
                    newVoxelCountX = parts[2].toInt();
                    // Note: In the file, Y is depth and Z is height
                    newVoxelCountZ = parts[3].toInt();
                    newVoxelCountY = parts[4].toInt();
                }
            } else if (line.contains("VoxelSize:")) {
                QStringList parts = line.split(" ");
                if (parts.size() >= 3) {
                    newVoxelSize = parts[2].toFloat();
                }
            } else if (line.contains("Spacing:")) {
                QStringList parts = line.split(" ");
                if (parts.size() >= 3) {
                    newSpacing = parts[2].toFloat();
                }
            }
            continue;
        }

        // Process voxel data to find max dimensions if not specified in comments
        QStringList parts = line.split(" ");
        if (parts.size() >= 4) {
            int x = parts[0].toInt();
            // In text format: Y is depth, Z is height
            int z = parts[1].toInt(); // This is depth in our system
            int y = parts[2].toInt(); // This is height in our system

            // Update dimensions based on voxel coordinates
            newVoxelCountX = qMax(newVoxelCountX, x + 1);
            newVoxelCountY = qMax(newVoxelCountY, y + 1);
            newVoxelCountZ = qMax(newVoxelCountZ, z + 1);
        }
    }

    // Update dimensions and reset voxel array
    m_voxelCountX = newVoxelCountX;
    m_voxelCountY = newVoxelCountY;
    m_voxelCountZ = newVoxelCountZ;
    m_voxelSize = newVoxelSize;
    m_spacing = newSpacing;

    m_voxels.resize(m_voxelCountX * m_voxelCountY * m_voxelCountZ);
    m_voxels.fill(Qt::transparent);

    // Second pass: read voxel data
    in.seek(0);
    while (!in.atEnd()) {
        line = in.readLine().trimmed();

        // Skip empty lines and comments
        if (line.isEmpty() || line.startsWith("#")) continue;

        QStringList parts = line.split(" ");
        if (parts.size() >= 4) {
            int x = parts[0].toInt();
            // In text format: Y is depth, Z is height
            int z = newVoxelCountZ-parts[1].toInt(); // This is depth in our system
            int y = parts[2].toInt(); // This is height in our system

            // Check if coordinates are within bounds
            if (x >= 0 && x < m_voxelCountX && y >= 0 && y < m_voxelCountY && z >= 0 && z < m_voxelCountZ) {
                // Parse color (RRGGBB format)
                QString colorStr = parts[3];
                bool ok;
                int colorValue = colorStr.toInt(&ok, 16);

                if (ok) {
                    QColor color;
                    if (colorStr.length() <= 6) {
                        // RRGGBB format
                        color = QColor(
                            (colorValue >> 16) & 0xFF,
                            (colorValue >> 8) & 0xFF,
                            colorValue & 0xFF,
                            255  // Full opacity
                        );
                    } else {
                        // RRGGBBAA format (if present)
                        color = QColor(
                            (colorValue >> 24) & 0xFF,
                            (colorValue >> 16) & 0xFF,
                            (colorValue >> 8) & 0xFF,
                            colorValue & 0xFF
                        );
                    }

                    m_voxels[indexOf(x, y, z)] = color;
                }
            }
        }
    }

    file.close();

    emit voxelCountXChanged();
    emit voxelCountYChanged();
    emit voxelCountZChanged();
    emit voxelSizeChanged();
    notifyDataChanged();
    return true;
}

void VoxelMapData::commit()
{
    notifyDataChanged();
}

void VoxelMapData::notifyDataChanged()
{
    if (m_onDataChanged)  m_onDataChanged();
}
