#include "voxelmapgeometry.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QVector3D>
#include <random>
#include <chrono>

/*!
    \qmltype VoxelMapGeometry
    \nativetype VoxelMapGeometry
    \inqmlmodule Clayground.Canvas3D
    \brief Optimized geometry for static voxel maps using greedy meshing.

    VoxelMapGeometry generates efficient mesh geometry for voxel-based
    3D structures. It uses a greedy meshing algorithm to combine adjacent
    voxels of the same color into larger quads, significantly reducing
    vertex count for large voxel maps.

    This geometry is used internally by StaticVoxelMap and is ideal for
    voxel structures that don't change frequently.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    Model {
        geometry: VoxelMapGeometry {
            voxelCountX: 10
            voxelCountY: 10
            voxelCountZ: 10
            voxelSize: 1.0
        }
        materials: CustomMaterial { }
    }
    \endqml

    \sa StaticVoxelMap, VoxelMapInstancing
*/

/*!
    \qmlproperty int VoxelMapGeometry::voxelCountX
    \brief Number of voxels along the X axis.
*/

/*!
    \qmlproperty int VoxelMapGeometry::voxelCountY
    \brief Number of voxels along the Y axis (height).
*/

/*!
    \qmlproperty int VoxelMapGeometry::voxelCountZ
    \brief Number of voxels along the Z axis.
*/

/*!
    \qmlproperty real VoxelMapGeometry::voxelSize
    \brief Size of each voxel cube in world units.

    Defaults to 1.0.
*/

/*!
    \qmlproperty real VoxelMapGeometry::spacing
    \brief Gap between adjacent voxels in world units.

    Defaults to 0.0 for solid voxel structures.
*/

/*!
    \qmlproperty int VoxelMapGeometry::vertexCount
    \readonly
    \brief The current number of vertices in the generated geometry.

    Useful for monitoring mesh complexity after greedy meshing optimization.
*/

/*!
    \qmlmethod color VoxelMapGeometry::voxel(int x, int y, int z)
    \brief Returns the color of the voxel at the specified coordinates.

    Returns transparent if the coordinates are out of bounds or the
    voxel is empty.
*/

/*!
    \qmlmethod void VoxelMapGeometry::setVoxel(int x, int y, int z, color color)
    \brief Sets the color of the voxel at the specified coordinates.

    Setting a voxel to transparent removes it from the map.
*/

/*!
    \qmlmethod void VoxelMapGeometry::fillSphere(int cx, int cy, int cz, int r, list colorDistribution, real noiseFactor)
    \brief Fills a spherical region with voxels.

    Creates a sphere centered at (cx, cy, cz) with radius r. The
    colorDistribution parameter specifies colors and their weights.
    The noiseFactor adds randomness to the sphere surface.
*/

/*!
    \qmlmethod void VoxelMapGeometry::fillCylinder(int cx, int cy, int cz, int r, int height, list colorDistribution, real noiseFactor)
    \brief Fills a cylindrical region with voxels.

    Creates a cylinder with center base at (cx, cy, cz), radius r,
    and specified height. Colors are distributed according to
    colorDistribution weights.
*/

/*!
    \qmlmethod void VoxelMapGeometry::fillBox(int cx, int cy, int cz, int width, int height, int depth, list colorDistribution, real noiseFactor)
    \brief Fills a box-shaped region with voxels.

    Creates a rectangular region starting at (cx, cy, cz) with the
    specified dimensions. Colors are distributed according to
    colorDistribution weights.
*/

/*!
    \qmlmethod bool VoxelMapGeometry::saveToFile(string path)
    \brief Saves the voxel map to a text file.

    Returns true if the save was successful.
*/

/*!
    \qmlmethod bool VoxelMapGeometry::loadFromFile(string path)
    \brief Loads a voxel map from a text file.

    Returns true if the load was successful.
*/

/*!
    \qmlmethod void VoxelMapGeometry::commit()
    \brief Triggers geometry regeneration after batch voxel operations.

    Call this once after multiple setVoxel or fill operations to
    update the mesh efficiently.
*/

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
    connect(&m_data, &VoxelMapData::voxelCountXChanged, this, &VoxelMapGeometry::voxelCountXChanged);
    connect(&m_data, &VoxelMapData::voxelCountYChanged, this, &VoxelMapGeometry::voxelCountYChanged);
    connect(&m_data, &VoxelMapData::voxelCountZChanged, this, &VoxelMapGeometry::voxelCountZChanged);
    connect(&m_data, &VoxelMapData::voxelSizeChanged, this, &VoxelMapGeometry::voxelSizeChanged);
    connect(&m_data, &VoxelMapData::spacingChanged, this, &VoxelMapGeometry::spacingChanged);
}

int VoxelMapGeometry::voxelCountX() const
{
    return m_data.voxelCountX();
}

void VoxelMapGeometry::setVoxelCountX(int count)
{
    m_data.setVoxelCountX(count);
}

int VoxelMapGeometry::voxelCountY() const
{
    return m_data.voxelCountY();
}

void VoxelMapGeometry::setVoxelCountY(int count)
{
    m_data.setVoxelCountY(count);
}

int VoxelMapGeometry::voxelCountZ() const
{
    return m_data.voxelCountZ();
}

void VoxelMapGeometry::setVoxelCountZ(int count)
{
    m_data.setVoxelCountZ(count);
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
bool VoxelMapGeometry::saveToFile(const QString &path)
{
    return m_data.saveToFile(path);
}

bool VoxelMapGeometry::loadFromFile(const QString &path)
{
    return m_data.loadFromFile(path);
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
    if (nx < 0 || nx >= m_data.voxelCountX() || ny < 0 || ny >= m_data.voxelCountY() || nz < 0 || nz >= m_data.voxelCountZ())
        return true;

    // Face is visible if neighbor voxel is transparent
    return m_data.voxel(nx, ny, nz).alpha() == 0;
}

// Build all voxel cubes in a single geometry using greedy meshing
void VoxelMapGeometry::updateGeometry()
{
    clear();
    if (m_data.voxelCountX() <= 0 || m_data.voxelCountY() <= 0 || m_data.voxelCountZ() <= 0)
        return;

    // Calculate the total size including spacing
    float totalWidth = m_data.voxelCountX() * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();
    float totalHeight = m_data.voxelCountY() * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();
    float totalDepth = m_data.voxelCountZ() * (m_data.voxelSize() + m_data.spacing()) - m_data.spacing();

    // Update bounds calculation
    float halfWidth = totalWidth / 2.0f;
    float maxHeight = totalHeight;
    float halfDepth = totalDepth / 2.0f;
    setBounds(QVector3D(-halfWidth, 0, -halfDepth),
             QVector3D(halfWidth, maxHeight, halfDepth));

    // Generate greedy quads
    QVector<GreedyQuad> quads = generateGreedyQuads();
    
    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    // Reserve approximate space (4 vertices per quad)
    vertexBuffer.reserve(quads.size() * 4 * sizeof(float) * 10);
    indexBuffer.reserve(quads.size() * 6 * sizeof(quint32));

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
    float voxelStep = m_data.voxelSize() + m_data.spacing();

    // Process each greedy quad
    for (const GreedyQuad& quad : quads) {
        // Calculate the starting position of the quad
        float startX = offsetX + quad.x * voxelStep;
        float startY = quad.y * voxelStep;
        float startZ = offsetZ + quad.z * voxelStep;
        
        // Calculate quad dimensions in world space
        float quadWidth, quadHeight, quadDepth;
        QVector3D v0, v1, v2, v3;
        
        // Generate vertices based on face orientation
        switch(quad.faceIndex) {
            case 0: // Front (-Z)
                quadWidth = quad.width * voxelStep - m_data.spacing();
                quadHeight = quad.height * voxelStep - m_data.spacing();
                v0 = QVector3D(startX, startY, startZ);
                v1 = QVector3D(startX, startY + quadHeight, startZ);
                v2 = QVector3D(startX + quadWidth, startY + quadHeight, startZ);
                v3 = QVector3D(startX + quadWidth, startY, startZ);
                break;
                
            case 1: // Right (+X)
                quadDepth = quad.width * voxelStep - m_data.spacing();
                quadHeight = quad.height * voxelStep - m_data.spacing();
                v0 = QVector3D(startX + m_data.voxelSize(), startY, startZ);
                v1 = QVector3D(startX + m_data.voxelSize(), startY + quadHeight, startZ);
                v2 = QVector3D(startX + m_data.voxelSize(), startY + quadHeight, startZ + quadDepth);
                v3 = QVector3D(startX + m_data.voxelSize(), startY, startZ + quadDepth);
                break;
                
            case 2: // Back (+Z)
                quadWidth = quad.width * voxelStep - m_data.spacing();
                quadHeight = quad.height * voxelStep - m_data.spacing();
                v0 = QVector3D(startX + quadWidth, startY, startZ + m_data.voxelSize());
                v1 = QVector3D(startX + quadWidth, startY + quadHeight, startZ + m_data.voxelSize());
                v2 = QVector3D(startX, startY + quadHeight, startZ + m_data.voxelSize());
                v3 = QVector3D(startX, startY, startZ + m_data.voxelSize());
                break;
                
            case 3: // Left (-X)
                quadDepth = quad.width * voxelStep - m_data.spacing();
                quadHeight = quad.height * voxelStep - m_data.spacing();
                v0 = QVector3D(startX, startY, startZ + quadDepth);
                v1 = QVector3D(startX, startY + quadHeight, startZ + quadDepth);
                v2 = QVector3D(startX, startY + quadHeight, startZ);
                v3 = QVector3D(startX, startY, startZ);
                break;
                
            case 4: // Top (+Y)
                quadWidth = quad.width * voxelStep - m_data.spacing();
                quadDepth = quad.height * voxelStep - m_data.spacing();
                v0 = QVector3D(startX, startY + m_data.voxelSize(), startZ);
                v1 = QVector3D(startX, startY + m_data.voxelSize(), startZ + quadDepth);
                v2 = QVector3D(startX + quadWidth, startY + m_data.voxelSize(), startZ + quadDepth);
                v3 = QVector3D(startX + quadWidth, startY + m_data.voxelSize(), startZ);
                break;
                
            case 5: // Bottom (-Y)
                quadWidth = quad.width * voxelStep - m_data.spacing();
                quadDepth = quad.height * voxelStep - m_data.spacing();
                v0 = QVector3D(startX, startY, startZ);
                v1 = QVector3D(startX + quadWidth, startY, startZ);
                v2 = QVector3D(startX + quadWidth, startY, startZ + quadDepth);
                v3 = QVector3D(startX, startY, startZ + quadDepth);
                break;
        }
        
        // Add the 4 vertices for this quad
        QVector3D vertices[4] = {v0, v1, v2, v3};
        for (const QVector3D& vertex : vertices) {
            // Position
            vertexBuffer.append(reinterpret_cast<const char*>(&vertex), sizeof(QVector3D));
            // Color
            float rgba[4] = { quad.color.redF(), quad.color.greenF(), quad.color.blueF(), quad.color.alphaF() };
            vertexBuffer.append(reinterpret_cast<const char*>(rgba), 4 * sizeof(float));
            // Normal
            vertexBuffer.append(reinterpret_cast<const char*>(&normals[quad.faceIndex]), sizeof(QVector3D));
        }
        
        // Add indices for the quad (2 triangles, maintaining CCW winding)
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
    
    // Track and emit vertex count
    if (m_vertexCount != vertexCount) {
        m_vertexCount = vertexCount;
        emit vertexCountChanged();
    }
}

void VoxelMapGeometry::commit()
{
    m_data.commit();
}

QVector<VoxelMapGeometry::GreedyQuad> VoxelMapGeometry::generateGreedyQuads()
{
    QVector<GreedyQuad> quads;
    
    // For each face direction
    for (int faceIndex = 0; faceIndex < 6; ++faceIndex) {
        // Determine the axes for this face
        // axis0 and axis1 are the two axes that form the plane of the face
        // axis2 is the axis perpendicular to the face
        int axis0, axis1, axis2;
        bool reverseOrder = false;
        
        switch(faceIndex) {
            case 0: // Front (-Z)
            case 2: // Back (+Z)
                axis0 = 0; axis1 = 1; axis2 = 2;
                reverseOrder = (faceIndex == 0);
                break;
            case 1: // Right (+X)
            case 3: // Left (-X)
                axis0 = 2; axis1 = 1; axis2 = 0;
                reverseOrder = (faceIndex == 3);
                break;
            case 4: // Top (+Y)
            case 5: // Bottom (-Y)
                axis0 = 0; axis1 = 2; axis2 = 1;
                reverseOrder = (faceIndex == 5);
                break;
        }
        
        int dim[3] = {m_data.voxelCountX(), m_data.voxelCountY(), m_data.voxelCountZ()};
        
        // Process each slice perpendicular to this face
        for (int slice = 0; slice < dim[axis2]; ++slice) {
            // Create a 2D mask for this slice
            QVector<QColor> mask(dim[axis0] * dim[axis1], Qt::transparent);
            
            // Fill the mask with visible face colors
            for (int a1 = 0; a1 < dim[axis1]; ++a1) {
                for (int a0 = 0; a0 < dim[axis0]; ++a0) {
                    int pos[3];
                    pos[axis0] = a0;
                    pos[axis1] = a1;
                    pos[axis2] = slice;
                    
                    // Check if this voxel exists and if this face is visible
                    QColor voxelColor = m_data.voxel(pos[0], pos[1], pos[2]);
                    if (voxelColor.alpha() > 0 && isFaceVisible(pos[0], pos[1], pos[2], faceIndex)) {
                        mask[a0 + a1 * dim[axis0]] = voxelColor;
                    }
                }
            }
            
            // Apply greedy meshing to this slice
            QVector<bool> processed(dim[axis0] * dim[axis1], false);
            
            for (int a1 = 0; a1 < dim[axis1]; ++a1) {
                for (int a0 = 0; a0 < dim[axis0]; ++a0) {
                    int idx = a0 + a1 * dim[axis0];
                    
                    // Skip if already processed or not visible
                    if (processed[idx] || mask[idx].alpha() == 0) continue;
                    
                    QColor quadColor = mask[idx];
                    
                    // Find the width of this quad (extend in axis0 direction)
                    int quadWidth = 1;
                    while (a0 + quadWidth < dim[axis0]) {
                        int checkIdx = (a0 + quadWidth) + a1 * dim[axis0];
                        if (processed[checkIdx] || mask[checkIdx] != quadColor) break;
                        quadWidth++;
                    }
                    
                    // Find the height of this quad (extend in axis1 direction)
                    int quadHeight = 1;
                    bool canExtend = true;
                    while (a1 + quadHeight < dim[axis1] && canExtend) {
                        // Check if we can extend the entire width
                        for (int w = 0; w < quadWidth; ++w) {
                            int checkIdx = (a0 + w) + (a1 + quadHeight) * dim[axis0];
                            if (processed[checkIdx] || mask[checkIdx] != quadColor) {
                                canExtend = false;
                                break;
                            }
                        }
                        if (canExtend) quadHeight++;
                    }
                    
                    // Mark all voxels in this quad as processed
                    for (int h = 0; h < quadHeight; ++h) {
                        for (int w = 0; w < quadWidth; ++w) {
                            processed[(a0 + w) + (a1 + h) * dim[axis0]] = true;
                        }
                    }
                    
                    // Create the greedy quad
                    GreedyQuad quad;
                    quad.x = quad.y = quad.z = 0;
                    
                    // Set the position based on the face orientation
                    int pos[3];
                    pos[axis0] = a0;
                    pos[axis1] = a1;
                    pos[axis2] = slice;
                    quad.x = pos[0];
                    quad.y = pos[1];
                    quad.z = pos[2];
                    
                    // Set dimensions in the correct axes
                    quad.width = quadWidth;
                    quad.height = quadHeight;
                    
                    quad.color = quadColor;
                    quad.faceIndex = faceIndex;
                    
                    quads.append(quad);
                }
            }
        }
    }
    
    return quads;
}

