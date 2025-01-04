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

QColor VoxelMapGeometry::voxelColor(int x, int y, int z) const
{
    if (x<0 || x>=m_width || y<0 || y>=m_height || z<0 || z>=m_depth)
        return Qt::transparent;
    return m_voxels[indexOf(x,y,z)];
}

void VoxelMapGeometry::setVoxelColor(int x, int y, int z, const QColor &color)
{
    if (x<0 || x>=m_width || y<0 || y>=m_height || z<0 || z>=m_depth)
        return;
    int idx = indexOf(x,y,z);
    if (m_voxels[idx] == color)
        return;
    m_voxels[idx] = color;
    updateGeometry();
}

// Build all voxel cubes in a single geometry
void VoxelMapGeometry::updateGeometry()
{
    clear();
    if (m_width <= 0 || m_height <= 0 || m_depth <= 0)
        return;

    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    vertexBuffer.reserve(m_width * m_height * m_depth * 8 * sizeof(float) * 7);
    indexBuffer.reserve(m_width * m_height * m_depth * 36 * sizeof(quint32));

    int vertexCount = 0;

    // Each voxel is a small cube, 8 corners, 36 indices (12 triangles).
    // We'll store positions + RGBA as the geometry attributes.
    for (int z = 0; z < m_depth; ++z) {
        for (int y = 0; y < m_height; ++y) {
            for (int x = 0; x < m_width; ++x) {
                QColor c = m_voxels[indexOf(x,y,z)];
                if (c.alpha() == 0) {
                    continue; // ignore "empty" or fully transparent voxels
                }

                float fx = x * m_voxelSize;
                float fy = y * m_voxelSize;
                float fz = z * m_voxelSize;
                float s = m_voxelSize;

                // 8 corners, pos + color
                QVector3D corners[8] = {
                                        { fx,    fy,    fz    },
                                        { fx+s,  fy,    fz    },
                                        { fx+s,  fy+s,  fz    },
                                        { fx,    fy+s,  fz    },
                                        { fx,    fy,    fz+s  },
                                        { fx+s,  fy,    fz+s  },
                                        { fx+s,  fy+s,  fz+s  },
                                        { fx,    fy+s,  fz+s  },
                                        };

                // Add vertex data
                for (int i = 0; i < 8; ++i) {
                    // position
                    vertexBuffer.append(reinterpret_cast<const char*>(&corners[i]), sizeof(QVector3D));
                    // color as RGBA floats
                    float rgba[4] = { c.redF(), c.greenF(), c.blueF(), c.alphaF() };
                    vertexBuffer.append(reinterpret_cast<const char*>(rgba), 4 * sizeof(float));
                }

                // 36 indices for 12 triangles (6 faces)
                static const quint32 inds[36] = {
                    // Front face (CCW)
                    0,2,1, 0,3,2,
                    // Right face
                    1,6,5, 1,2,6,
                    // Back face
                    5,7,4, 5,6,7,
                    // Left face
                    4,3,0, 4,7,3,
                    // Top face
                    3,6,2, 3,7,6,
                    // Bottom face
                    4,1,5, 4,0,1
                };
                for (int i = 0; i < 36; ++i) {
                    quint32 globalIdx = vertexCount + inds[i];
                    indexBuffer.append(reinterpret_cast<const char*>(&globalIdx), sizeof(quint32));
                }
                vertexCount += 8;
            }
        }
    }

    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);

    setStride((3 + 4) * sizeof(float)); // position + color
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::ColorSemantic,
                 3 * sizeof(float),
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
                setVoxelColor(x, y, z, stringToColor(colorStr));
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
