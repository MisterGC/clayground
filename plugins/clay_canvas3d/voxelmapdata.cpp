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

void VoxelMapData::setWidth(int w)
{
    if (m_width == w)
        return;
    m_width = w;
    m_voxels.resize(m_width * m_height * m_depth);
    m_voxels.fill(Qt::transparent);
    emit widthChanged();
    notifyDataChanged();
}

void VoxelMapData::setHeight(int h)
{
    if (m_height == h)
        return;
    m_height = h;
    m_voxels.resize(m_width * m_height * m_depth);
    m_voxels.fill(Qt::transparent);
    emit heightChanged();
    notifyDataChanged();
}

void VoxelMapData::setDepth(int d)
{
    if (m_depth == d)
        return;
    m_depth = d;
    m_voxels.resize(m_width * m_height * m_depth);
    m_voxels.fill(Qt::transparent);
    emit depthChanged();
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
    if (x < 0 || x >= m_width || y < 0 || y >= m_height || z < 0 || z >= m_depth)
        return Qt::transparent;
    return m_voxels[indexOf(x, y, z)];
}

void VoxelMapData::setVoxel(int x, int y, int z, const QColor &color)
{
    if (x < 0 || x >= m_width || y < 0 || y >= m_height || z < 0 || z >= m_depth)
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
    if (cx >= width() + r || cy >= height() + r || cz >= depth() + r) return;

    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty()) return;

    float maxRadius = r * (1.0f + noiseFactor);
    float baseR2 = (r - 0.5f) * (r - 0.5f);

    int minX = qBound(0, int(cx - maxRadius), width() - 1);
    int maxX = qBound(0, int(cx + maxRadius), width() - 1);
    int minY = qBound(0, int(cy - maxRadius), height() - 1);
    int maxY = qBound(0, int(cy + maxRadius), height() - 1);
    int minZ = qBound(0, int(cz - maxRadius), depth() - 1);
    int maxZ = qBound(0, int(cz + maxRadius), depth() - 1);

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
    if (cx >= width() + r || cy >= this->height() + height || cz >= depth() + r) return;

    auto distribution = prepareColorDistribution(colorDistribution);
    if (distribution.isEmpty()) return;

    float maxRadius = r * (1.0f + noiseFactor);
    float baseR2 = (r - 0.5f) * (r - 0.5f);

    int minX = qBound(0, int(cx - maxRadius), width() - 1);
    int maxX = qBound(0, int(cx + maxRadius), width() - 1);
    int minY = qBound(0, int(cy), this->height() - 1);
    int maxY = qBound(0, int(cy + height), this->height() - 1);
    int minZ = qBound(0, int(cz - maxRadius), depth() - 1);
    int maxZ = qBound(0, int(cz + maxRadius), depth() - 1);

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
    int maxX = qBound(0, minX + boxWidth - 1, width() - 1);
    int maxY = qBound(0, minY + boxHeight - 1, height() - 1);
    int maxZ = qBound(0, minZ + boxDepth - 1, depth() - 1);
    minX = qBound(0, minX, width() - 1);
    minY = qBound(0, minY, height() - 1);
    minZ = qBound(0, minZ, depth() - 1);

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

bool VoxelMapData::saveToFile(const QString &path, bool binary)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Could not open for writing:" << path;
        return false;
    }
    if (binary) {
        QDataStream out(&file);
        out << m_width << m_height << m_depth << m_voxelSize;
        for (const auto &col : m_voxels) {
            out << col.rgba(); // store 32-bit RGBA
        }
    } else {
        QTextStream ts(&file);
        ts << "width: " << m_width << "\n"
           << "height: " << m_height << "\n"
           << "depth: " << m_depth << "\n"
           << "voxelSize: " << m_voxelSize << "\n"
           << "voxels:\n";
        for (int z=0; z<m_depth; ++z) {
            for (int y=0; y<m_height; ++y) {
                for (int x=0; x<m_width; ++x) {
                    QColor c = m_voxels[indexOf(x,y,z)];
                    if (c.alpha() != 0) {
                        ts << "  - xyz: [" << x << "," << y << "," << z << "] color: "
                           << colorToString(c) << "\n";
                    }
                }
            }
        }
    }
    return true;
}

bool VoxelMapData::loadFromFile(const QString &path, bool binary)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Could not open for reading:" << path;
        return false;
    }
    if (binary) {
        QDataStream in(&file);
        in >> m_width >> m_height >> m_depth >> m_voxelSize;
        m_voxels.resize(m_width * m_height * m_depth);
        for (int i = 0; i < m_voxels.size(); ++i) {
            QRgb val;
            in >> val;
            m_voxels[i].setRgba(val);
        }
    } else {
        QTextStream ts(&file);
        m_voxels.clear();
        m_width = m_height = m_depth = 0;
        while (!ts.atEnd()) {
            QString line = ts.readLine().trimmed();
            if (line.startsWith("width:"))
                m_width = line.split(":").last().trimmed().toInt();
            else if (line.startsWith("height:"))
                m_height = line.split(":").last().trimmed().toInt();
            else if (line.startsWith("depth:"))
                m_depth = line.split(":").last().trimmed().toInt();
            else if (line.startsWith("voxelSize:"))
                m_voxelSize = line.split(":").last().trimmed().toFloat();
        }
        // Rewind to parse voxel lines
        file.seek(0);
        ts.seek(0);
        m_voxels.resize(m_width * m_height * m_depth);
        while (!ts.atEnd()) {
            QString line = ts.readLine().trimmed();
            if (line.startsWith("- xyz:")) {
                int start = line.indexOf('[') + 1;
                int end = line.indexOf(']');
                QStringList coords = line.mid(start, end - start).split(',');
                int x = coords[0].toInt();
                int y = coords[1].toInt();
                int z = coords[2].toInt();

                int colorPos = line.indexOf("color:") + 6;
                QString colorStr = line.mid(colorPos).trimmed();
                setVoxel(x, y, z, stringToColor(colorStr));
            }
        }
    }
    emit widthChanged();
    emit heightChanged();
    emit depthChanged();
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
