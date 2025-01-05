#include "voxelmapgeometry.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QVector3D>

// Optional: for a simple YAML-like approach. Real projects may use a full YAML library.
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

VoxelMapGeometry::VoxelMapGeometry()
{
}

void VoxelMapGeometry::setWidth(int w)
{
    if (m_width == w)
        return;
    m_width = w;
    m_voxels.fill(m_defaultColor, m_width * m_height * m_depth);
    emit widthChanged();
    updateGeometry();
}

void VoxelMapGeometry::setHeight(int h)
{
    if (m_height == h)
        return;
    m_height = h;
    m_voxels.fill(m_defaultColor, m_width * m_height * m_depth);
    emit heightChanged();
    updateGeometry();
}

void VoxelMapGeometry::setDepth(int d)
{
    if (m_depth == d)
        return;
    m_depth = d;
    m_voxels.fill(m_defaultColor, m_width * m_height * m_depth);
    emit depthChanged();
    updateGeometry();
}

void VoxelMapGeometry::setVoxelSize(float size)
{
    if (qFuzzyCompare(m_voxelSize, size))
        return;
    m_voxelSize = size;
    emit voxelSizeChanged();
    updateGeometry();
}

void VoxelMapGeometry::setDefaultColor(const QColor &color)
{
    if (m_defaultColor == color)
        return;
    m_defaultColor = color;
    emit defaultColorChanged();
    updateGeometry();
}

QColor VoxelMapGeometry::voxel(int x, int y, int z) const
{
    if (x<0 || x>=m_width || y<0 || y>=m_height || z<0 || z>=m_depth)
        return Qt::transparent;
    return m_voxels[indexOf(x,y,z)];
}

void VoxelMapGeometry::setVoxel(int x, int y, int z, const QColor &color)
{
    if (x<0 || x>=m_width || y<0 || y>=m_height || z<0 || z>=m_depth)
        return;
    int idx = indexOf(x,y,z);
    if (m_voxels[idx] == color)
        return;
    m_voxels[idx] = color;
    updateGeometry();
}

void VoxelMapGeometry::fillSphere(int cx, int cy, int cz,
                              int r,
                              const QColor &color)
{
    // Validate inputs
    if (r <= 0.0f) return;
    if (cx < -r || cy < -r || cz < -r) return;
    if (cx >= width() + r || cy >= height() + r || cz >= depth() + r) return;

    // Precompute r^2 to avoid repeated multiplications
    float r2 = r * r;

    // Find bounding box that encloses the sphere
    // Using qBound to ensure values stay within valid range
    int minX = qBound(0, int(cx - r), width() - 1);
    int maxX = qBound(0, int(cx + r), width() - 1);
    int minY = qBound(0, int(cy - r), height() - 1);
    int maxY = qBound(0, int(cy + r), height() - 1);
    int minZ = qBound(0, int(cz - r), depth() - 1);
    int maxZ = qBound(0, int(cz + r), depth() - 1);

    // Early return if no valid voxels to fill
    if (minX > maxX || minY > maxY || minZ > maxZ) return;

    for (int z = minZ; z <= maxZ; ++z) {
        for (int y = minY; y <= maxY; ++y) {
            for (int x = minX; x <= maxX; ++x) {
                float dx = float(x - cx);
                float dy = float(y - cy);
                float dz = float(z - cz);
                if (dx*dx + dy*dy + dz*dz <= r2) {
                    m_voxels[indexOf(x,y,z)] = color;
                }
            }
        }
    }

    updateGeometry();
}

bool VoxelMapGeometry::isFaceVisible(int x, int y, int z, int faceIndex) const {
    // Get the neighbor coordinates based on face index
    int nx = x, ny = y, nz = z;
    switch(faceIndex) {
        case 0: nz--; break; // Front
        case 1: nx++; break; // Right
        case 2: nz++; break; // Back
        case 3: nx--; break; // Left
        case 4: ny++; break; // Top
        case 5: ny--; break; // Bottom
    }

    // If neighbor is outside bounds, face is visible
    if (nx < 0 || nx >= m_width || ny < 0 || ny >= m_height || nz < 0 || nz >= m_depth)
        return true;

    // Face is visible if neighbor voxel is transparent
    return m_voxels[indexOf(nx, ny, nz)].alpha() == 0;
}

// Build all voxel cubes in a single geometry
void VoxelMapGeometry::updateGeometry()
{
    clear();
    if (m_width <= 0 || m_height <= 0 || m_depth <= 0)
        return;

    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    // 24 vertices per cube (4 vertices per face * 6 faces)
    vertexBuffer.reserve(m_width * m_height * m_depth * 24 * sizeof(float) * 10);
    // 36 indices per cube (6 indices per face * 6 faces)
    indexBuffer.reserve(m_width * m_height * m_depth * 36 * sizeof(quint32));

    int vertexCount = 0;

    // Define the normals for each face
    static const QVector3D normals[6] = {
        { 0.0f,  0.0f, -1.0f }, // Front
        { 1.0f,  0.0f,  0.0f }, // Right
        { 0.0f,  0.0f,  1.0f }, // Back
        {-1.0f,  0.0f,  0.0f }, // Left
        { 0.0f,  1.0f,  0.0f }, // Top
        { 0.0f, -1.0f,  0.0f }  // Bottom
    };

    for (int z = 0; z < m_depth; ++z) {
        for (int y = 0; y < m_height; ++y) {
            for (int x = 0; x < m_width; ++x) {
                QColor c = m_voxels[indexOf(x,y,z)];
                if (c.alpha() == 0) continue;

                float fx = x * m_voxelSize;
                float fy = y * m_voxelSize;
                float fz = z * m_voxelSize;
                float s = m_voxelSize;

                // Define vertices for each face (4 vertices per face)
                struct Face {
                    QVector3D vertices[4];
                    const QVector3D& normal;
                };

                Face faces[6] = {
                    // Front face (CCW when looking at front)
                    {{{fx, fy, fz}, {fx, fy+s, fz}, {fx+s, fy+s, fz}, {fx+s, fy, fz}}, normals[0]},
                    // Right face (CCW when looking from right)
                    {{{fx+s, fy, fz}, {fx+s, fy+s, fz}, {fx+s, fy+s, fz+s}, {fx+s, fy, fz+s}}, normals[1]},
                    // Back face (CCW when looking at back)
                    {{{fx+s, fy, fz+s}, {fx+s, fy+s, fz+s}, {fx, fy+s, fz+s}, {fx, fy, fz+s}}, normals[2]},
                    // Left face (CCW when looking from left)
                    {{{fx, fy, fz+s}, {fx, fy+s, fz+s}, {fx, fy+s, fz}, {fx, fy, fz}}, normals[3]},
                    // Top face (CCW when looking from above)
                    {{{fx, fy+s, fz}, {fx, fy+s, fz+s}, {fx+s, fy+s, fz+s}, {fx+s, fy+s, fz}}, normals[4]},
                    // Bottom face (CCW when looking from below)
                    {{{fx, fy, fz}, {fx+s, fy, fz}, {fx+s, fy, fz+s}, {fx, fy, fz+s}}, normals[5]}
                };

                // Add vertices for each face
                for (int i = 0; i < 6; ++i) {
                    // Only add face if it's visible
                    if (isFaceVisible(x, y, z, i)) {
                        const Face& face = faces[i];
                        for (const QVector3D& vertex : face.vertices) {
                            // Position
                            vertexBuffer.append(reinterpret_cast<const char*>(&vertex), sizeof(QVector3D));
                            // Color
                            float rgba[4] = { c.redF(), c.greenF(), c.blueF(), c.alphaF() };
                            vertexBuffer.append(reinterpret_cast<const char*>(rgba), 4 * sizeof(float));
                            // Normal
                            vertexBuffer.append(reinterpret_cast<const char*>(&face.normal), sizeof(QVector3D));
                        }

                        // Add indices for the face (2 triangles, maintaining CCW winding)
                        quint32 indices[6] = {
                            static_cast<quint32>(vertexCount),
                            static_cast<quint32>(vertexCount + 1),
                            static_cast<quint32>(vertexCount + 2),
                            static_cast<quint32>(vertexCount),
                            static_cast<quint32>(vertexCount + 2),
                            static_cast<quint32>(vertexCount + 3)
                        };
                        indexBuffer.append(reinterpret_cast<const char*>(indices), 6 * sizeof(quint32));
                        vertexCount += 4;
                    }
                }
            }
        }
    }

    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);

    setStride((3 + 4 + 3) * sizeof(float)); // position + color + normal
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::ColorSemantic,
                 3 * sizeof(float),
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic,
                 7 * sizeof(float),
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic,
                 0,
                 QQuick3DGeometry::Attribute::U32Type);

    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    update(); // finalize
}

bool VoxelMapGeometry::saveToFile(const QString &path, bool binary)
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

bool VoxelMapGeometry::loadFromFile(const QString &path, bool binary)
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
        // Simple line-based parse for demonstration
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
                // example: "- xyz: [x,y,z] color: R,G,B,A"
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
    updateGeometry();
    return true;
}
