#include "voxelmapgeometry.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QVector3D>
#include <random>
#include <chrono>

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
    // Connect the data change notification to trigger geometry updates
    m_data.setOnDataChanged([this]() { updateGeometry(); });

    // Connect property change signals
    connect(&m_data, &VoxelMapData::widthChanged, this, &VoxelMapGeometry::widthChanged);
    connect(&m_data, &VoxelMapData::heightChanged, this, &VoxelMapGeometry::heightChanged);
    connect(&m_data, &VoxelMapData::depthChanged, this, &VoxelMapGeometry::depthChanged);
    connect(&m_data, &VoxelMapData::voxelSizeChanged, this, &VoxelMapGeometry::voxelSizeChanged);
    connect(&m_data, &VoxelMapData::spacingChanged, this, &VoxelMapGeometry::spacingChanged);
}

int VoxelMapGeometry::width() const
{
    return m_data.width();
}

void VoxelMapGeometry::setWidth(int w)
{
    m_data.setWidth(w);
}

int VoxelMapGeometry::height() const
{
    return m_data.height();
}

void VoxelMapGeometry::setHeight(int h)
{
    m_data.setHeight(h);
}

int VoxelMapGeometry::depth() const
{
    return m_data.depth();
}

void VoxelMapGeometry::setDepth(int d)
{
    m_data.setDepth(d);
}

float VoxelMapGeometry::voxelSize() const
{
    return m_data.voxelSize();
}

void VoxelMapGeometry::setVoxelSize(float size)
{
    m_data.setVoxelSize(size);
}

float VoxelMapGeometry::spacing() const
{
    return m_data.spacing();
}

void VoxelMapGeometry::setSpacing(float spacing)
{
    m_data.setSpacing(spacing);
}

// ==========================================
// Delegated Methods (for QML-invokable functions)
// ==========================================
bool VoxelMapGeometry::saveToFile(const QString &path, bool binary)
{
    return m_data.saveToFile(path, binary);
}

bool VoxelMapGeometry::loadFromFile(const QString &path, bool binary)
{
    return m_data.loadFromFile(path, binary);
}

QColor VoxelMapGeometry::voxel(int x, int y, int z) const {
    return m_data.voxel(x, y, z);
}

void VoxelMapGeometry::setVoxel(int x, int y, int z, const QColor &color) {
    m_data.setVoxel(x, y, z, color);
}

void VoxelMapGeometry::fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillSphere(cx, cy, cz, r, colorDistribution, noiseFactor);
}

void VoxelMapGeometry::fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillCylinder(cx, cy, cz, r, height, colorDistribution, noiseFactor);
}

void VoxelMapGeometry::fillBox(int cx, int cy, int cz, int width, int height, int depth, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillBox(cx, cy, cz, width, height, depth, colorDistribution, noiseFactor);
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
    if (nx < 0 || nx >= m_data.width() || ny < 0 || ny >= m_data.height() || nz < 0 || nz >= m_data.depth())
        return true;

    // Face is visible if neighbor voxel is transparent
    return m_data.voxel(nx, ny, nz).alpha() == 0;
}

// Build all voxel cubes in a single geometry
void VoxelMapGeometry::updateGeometry()
{
    clear();
    if (m_data.width() <= 0 || m_data.height() <= 0 || m_data.depth() <= 0)
        return;

    // Calculate the total size including spacing
    float totalWidth = m_data.width() * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();
    float totalHeight = m_data.height() * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();
    float totalDepth = m_data.depth() * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();

    // Update bounds calculation
    float halfWidth = totalWidth / 2.0f;
    float maxHeight = totalHeight;
    float halfDepth = totalDepth / 2.0f;
    setBounds(QVector3D(-halfWidth, 0, -halfDepth),
             QVector3D(halfWidth, maxHeight, halfDepth));

    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    // 24 vertices per cube (4 vertices per face * 6 faces)
    vertexBuffer.reserve(m_data.width() * m_data.height() * m_data.depth() * 24 * sizeof(float) * 10);
    // 36 indices per cube (6 indices per face * 6 faces)
    indexBuffer.reserve(m_data.width() * m_data.height() * m_data.depth() * 36 * sizeof(quint32));

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

    // Update the offset calculations
    float offsetX = -totalWidth / 2.0f;
    float offsetZ = -totalDepth / 2.0f;

    for (int z = 0; z < m_data.depth(); ++z) {
        for (int y = 0; y < m_data.height(); ++y) {
            for (int x = 0; x < m_data.width(); ++x) {
                QColor c = m_data.voxel(x,y,z);
                if (c.alpha() == 0) continue;

                // Update position calculations to include spacing
                float fx = offsetX + x * (m_data.voxelSize() + m_data.spacing());
                float fy = y * (m_data.voxelSize() + m_data.spacing());
                float fz = offsetZ + z * (m_data.voxelSize() + m_data.spacing());
                float s = m_data.voxelSize();

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
