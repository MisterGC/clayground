#include "voxelmapgeometry.h"
#include <QVector3D>
#include <QLoggingCategory>
#include <QtConcurrent>

// Temporary performance instrumentation. Silent by default; enable with
//   QT_LOGGING_RULES="clay.voxel.perf=true"
// to observe how many chunks a single edit re-meshes and how long it takes.
Q_LOGGING_CATEGORY(lcVoxelPerf, "clay.voxel.perf")

/*!
    \qmltype VoxelMapGeometry
    \nativetype VoxelMapGeometry
    \inqmlmodule Clayground.Canvas3D
    \brief Optimized geometry for static voxel maps using chunked greedy meshing.

    VoxelMapGeometry generates efficient mesh geometry for voxel-based
    3D structures. It uses a greedy meshing algorithm to combine adjacent
    voxels of the same color into larger quads, significantly reducing
    vertex count for large voxel maps.

    The volume is split into cubic chunks (see \l chunkSize). Only chunks
    touched by an edit are re-meshed, and meshing runs on worker threads; the
    resulting per-chunk buffers are concatenated into the single geometry buffer
    on the main thread. This keeps the geometry a single Model (one draw call,
    externally instanceable) while making incremental edits cheap.

    This geometry is used internally by StaticVoxelMap and is ideal for
    voxel structures that don't change every frame.

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
    \qmlproperty int VoxelMapGeometry::chunkSize
    \brief Edge length (in voxels) of a meshing chunk.

    The volume is divided into cubic chunks of this size. Only chunks affected
    by an edit are re-meshed, off the main thread. Defaults to 32. Changing this
    triggers a full re-mesh.
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

VoxelMapGeometry::VoxelMapGeometry()
{
    // Connect the data change notification to schedule chunk (re)meshing.
    m_data.setOnDataChanged([this]() { onDataChanged(); });

    // Connect property change signals
    connect(&m_data, &VoxelMapData::voxelCountXChanged, this, &VoxelMapGeometry::voxelCountXChanged);
    connect(&m_data, &VoxelMapData::voxelCountYChanged, this, &VoxelMapGeometry::voxelCountYChanged);
    connect(&m_data, &VoxelMapData::voxelCountZChanged, this, &VoxelMapGeometry::voxelCountZChanged);
    connect(&m_data, &VoxelMapData::voxelSizeChanged, this, &VoxelMapGeometry::voxelSizeChanged);
    connect(&m_data, &VoxelMapData::spacingChanged, this, &VoxelMapGeometry::spacingChanged);

    connect(&m_watcher, &QFutureWatcher<VoxelChunk::MeshResult>::finished,
            this, &VoxelMapGeometry::onMeshBatchFinished);
}

int VoxelMapGeometry::voxelCountX() const { return m_data.voxelCountX(); }
void VoxelMapGeometry::setVoxelCountX(int count) { m_data.setVoxelCountX(count); }
int VoxelMapGeometry::voxelCountY() const { return m_data.voxelCountY(); }
void VoxelMapGeometry::setVoxelCountY(int count) { m_data.setVoxelCountY(count); }
int VoxelMapGeometry::voxelCountZ() const { return m_data.voxelCountZ(); }
void VoxelMapGeometry::setVoxelCountZ(int count) { m_data.setVoxelCountZ(count); }

float VoxelMapGeometry::voxelSize() const { return m_data.voxelSize(); }
void VoxelMapGeometry::setVoxelSize(float size) { m_data.setVoxelSize(size); }
float VoxelMapGeometry::spacing() const { return m_data.spacing(); }
void VoxelMapGeometry::setSpacing(float spacing) { m_data.setSpacing(spacing); }

void VoxelMapGeometry::setChunkSize(int size)
{
    if (size <= 0 || size == m_chunkSize)
        return;
    m_chunkSize = size;
    emit chunkSizeChanged();
    m_pendingFull = true;
    maybeStartBatch();
}

// ==========================================
// Delegated Methods (for QML-invokable functions)
// ==========================================
bool VoxelMapGeometry::saveToFile(const QString &path) { return m_data.saveToFile(path); }
bool VoxelMapGeometry::loadFromFile(const QString &path) { return m_data.loadFromFile(path); }
QColor VoxelMapGeometry::voxel(int x, int y, int z) const { return m_data.voxel(x, y, z); }
void VoxelMapGeometry::setVoxel(int x, int y, int z, const QColor &color) { m_data.setVoxel(x, y, z, color); }

void VoxelMapGeometry::fillSphere(int cx, int cy, int cz, int r, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillSphere(cx, cy, cz, r, colorDistribution, noiseFactor);
}
void VoxelMapGeometry::fillCylinder(int cx, int cy, int cz, int r, int height, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillCylinder(cx, cy, cz, r, height, colorDistribution, noiseFactor);
}
void VoxelMapGeometry::fillBox(int cx, int cy, int cz, int width, int height, int depth, const QVariantList &colorDistribution, float noiseFactor) {
    m_data.fillBox(cx, cy, cz, width, height, depth, colorDistribution, noiseFactor);
}

void VoxelMapGeometry::commit() { m_data.commit(); }

// ==========================================
// Chunked async meshing
// ==========================================
void VoxelMapGeometry::onDataChanged()
{
    VoxelDirtyRegion dr = m_data.takeDirtyRegion();
    if (dr.full) {
        m_pendingFull = true;
    } else if (!dr.empty) {
        addChunksForRegion(dr);
    } else {
        // Only voxelSize/spacing changed: world positions of all quads move.
        m_pendingFull = true;
    }
    maybeStartBatch();
}

void VoxelMapGeometry::rebuildChunkGrid()
{
    const int cs = m_chunkSize;
    m_chunksX = m_data.voxelCountX() > 0 ? (m_data.voxelCountX() + cs - 1) / cs : 0;
    m_chunksY = m_data.voxelCountY() > 0 ? (m_data.voxelCountY() + cs - 1) / cs : 0;
    m_chunksZ = m_data.voxelCountZ() > 0 ? (m_data.voxelCountZ() + cs - 1) / cs : 0;
    const int total = m_chunksX * m_chunksY * m_chunksZ;
    m_chunkCache.clear();
    m_chunkCache.resize(total);
}

void VoxelMapGeometry::addChunksForRegion(const VoxelDirtyRegion &region)
{
    if (m_chunksX == 0 || m_chunksY == 0 || m_chunksZ == 0)
        return;

    const int cs = m_chunkSize;
    // Expand by one voxel so neighbour chunks re-cull faces at shared borders.
    const int x0 = qMax(0, region.minX - 1);
    const int y0 = qMax(0, region.minY - 1);
    const int z0 = qMax(0, region.minZ - 1);
    const int x1 = qMin(m_data.voxelCountX() - 1, region.maxX + 1);
    const int y1 = qMin(m_data.voxelCountY() - 1, region.maxY + 1);
    const int z1 = qMin(m_data.voxelCountZ() - 1, region.maxZ + 1);
    if (x1 < x0 || y1 < y0 || z1 < z0)
        return;

    for (int cz = z0 / cs; cz <= z1 / cs; ++cz)
        for (int cy = y0 / cs; cy <= y1 / cs; ++cy)
            for (int cx = x0 / cs; cx <= x1 / cs; ++cx)
                m_pendingDirty.insert(chunkIndex(cx, cy, cz));
}

void VoxelMapGeometry::maybeStartBatch()
{
    if (m_batchRunning)
        return;   // the finished handler will start the next batch
    startBatch();
}

VoxelChunk::MeshInput VoxelMapGeometry::buildChunkInput(int chunkId) const
{
    VoxelChunk::MeshInput in;
    in.chunkId = chunkId;

    const int cx = chunkId % m_chunksX;
    const int cy = (chunkId / m_chunksX) % m_chunksY;
    const int cz = chunkId / (m_chunksX * m_chunksY);

    const int cs = m_chunkSize;
    in.x0 = cx * cs;
    in.y0 = cy * cs;
    in.z0 = cz * cs;
    in.sizeX = qMin(cs, m_data.voxelCountX() - in.x0);
    in.sizeY = qMin(cs, m_data.voxelCountY() - in.y0);
    in.sizeZ = qMin(cs, m_data.voxelCountZ() - in.z0);

    const float voxelStep = m_data.voxelSize() + m_data.spacing();
    const float totalWidth = m_data.voxelCountX() * voxelStep - m_data.spacing();
    const float totalDepth = m_data.voxelCountZ() * voxelStep - m_data.spacing();
    in.voxelSize = m_data.voxelSize();
    in.spacing = m_data.spacing();
    in.voxelStep = voxelStep;
    in.offsetX = -totalWidth / 2.0f;
    in.offsetZ = -totalDepth / 2.0f;

    const int sx = in.sizeX + 2;
    const int sy = in.sizeY + 2;
    const int sz = in.sizeZ + 2;
    in.colors.resize(sx * sy * sz);
    for (int lz = -1; lz <= in.sizeZ; ++lz) {
        for (int ly = -1; ly <= in.sizeY; ++ly) {
            for (int lx = -1; lx <= in.sizeX; ++lx) {
                const QColor c = m_data.voxel(in.x0 + lx, in.y0 + ly, in.z0 + lz);
                const int idx = (lx + 1) + (ly + 1) * sx + (lz + 1) * sx * sy;
                in.colors[idx] = (c.alpha() == 0) ? QRgb(0) : c.rgba();
            }
        }
    }
    return in;
}

void VoxelMapGeometry::startBatch()
{
    bool didFull = false;
    if (m_pendingFull) {
        rebuildChunkGrid();
        m_pendingDirty.clear();
        for (int i = 0; i < m_chunkCache.size(); ++i)
            m_pendingDirty.insert(i);
        m_pendingFull = false;
        didFull = true;
    }

    if (m_data.voxelCountX() <= 0 || m_data.voxelCountY() <= 0 || m_data.voxelCountZ() <= 0) {
        m_chunkCache.clear();
        m_pendingDirty.clear();
        clear();
        update();
        if (m_vertexCount != 0) { m_vertexCount = 0; emit vertexCountChanged(); }
        return;
    }

    if (m_pendingDirty.isEmpty()) {
        concatenateAndUpload();
        return;
    }

    QVector<VoxelChunk::MeshInput> inputs;
    inputs.reserve(m_pendingDirty.size());
    for (int id : std::as_const(m_pendingDirty)) {
        if (id >= 0 && id < m_chunkCache.size())
            inputs.append(buildChunkInput(id));
    }
    m_pendingDirty.clear();

    if (inputs.isEmpty()) {
        concatenateAndUpload();
        return;
    }

    m_batchChunkCount = inputs.size();
    m_batchWasFull = didFull;
    m_batchRunning = true;
    m_batchTimer.restart();
    // Move the input sequence into the future so its lifetime is owned by the
    // running computation (avoids dangling references to this local).
    m_watcher.setFuture(QtConcurrent::mapped(std::move(inputs), VoxelChunk::buildMesh));
}

void VoxelMapGeometry::onMeshBatchFinished()
{
    const QList<VoxelChunk::MeshResult> results = m_watcher.future().results();
    for (const VoxelChunk::MeshResult &r : results) {
        if (r.chunkId >= 0 && r.chunkId < m_chunkCache.size())
            m_chunkCache[r.chunkId] = r;
    }
    m_batchRunning = false;

    const qint64 ms = m_batchTimer.elapsed();
    qCInfo(lcVoxelPerf).nospace() << "remesh " << m_batchChunkCount << " chunk(s) "
        << (m_batchWasFull ? "(full)" : "(incremental)") << " in " << ms
        << " ms; grid " << m_chunksX << "x" << m_chunksY << "x" << m_chunksZ
        << ", solids " << m_data.solidCount();

    concatenateAndUpload();

    // A new edit may have arrived while this batch was running.
    if (m_pendingFull || !m_pendingDirty.isEmpty())
        maybeStartBatch();
}

void VoxelMapGeometry::concatenateAndUpload()
{
    clear();

    const float voxelStep = m_data.voxelSize() + m_data.spacing();
    const float totalWidth = m_data.voxelCountX() * voxelStep - m_data.spacing();
    const float totalHeight = m_data.voxelCountY() * voxelStep - m_data.spacing();
    const float totalDepth = m_data.voxelCountZ() * voxelStep - m_data.spacing();
    const float halfWidth = totalWidth / 2.0f;
    const float halfDepth = totalDepth / 2.0f;
    setBounds(QVector3D(-halfWidth, 0, -halfDepth),
              QVector3D(halfWidth, totalHeight, halfDepth));

    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    quint32 baseVertex = 0;
    for (const VoxelChunk::MeshResult &c : std::as_const(m_chunkCache)) {
        if (c.vertexCount == 0)
            continue;
        vertexBuffer.append(c.vertices);
        // Rebase this chunk's local indices onto the running vertex offset.
        const int n = int(c.indices.size() / sizeof(quint32));
        const quint32 *src = reinterpret_cast<const quint32 *>(c.indices.constData());
        QByteArray rebased;
        rebased.resize(c.indices.size());
        quint32 *dst = reinterpret_cast<quint32 *>(rebased.data());
        for (int i = 0; i < n; ++i)
            dst[i] = src[i] + baseVertex;
        indexBuffer.append(rebased);
        baseVertex += quint32(c.vertexCount);
    }

    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);

    setStride((3 + 4 + 3) * sizeof(float)); // position + color + normal
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic, 0,
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::ColorSemantic, 3 * sizeof(float),
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic, 7 * sizeof(float),
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic, 0,
                 QQuick3DGeometry::Attribute::U32Type);
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    update();

    const int totalVerts = int(baseVertex);
    if (m_vertexCount != totalVerts) {
        m_vertexCount = totalVerts;
        emit vertexCountChanged();
    }
}
