#pragma once

#include <QByteArray>
#include <QVector>
#include <QRgb>

// Chunked greedy meshing that runs off the main thread.
//
// A VoxelMapGeometry is split into fixed-size cubic chunks. Each dirty chunk is
// meshed independently on a worker thread from an immutable snapshot of its
// voxels plus a one-voxel border (needed so face culling at chunk boundaries
// consults the neighbouring chunks). The resulting per-chunk vertex/index
// buffers are cached and concatenated on the main thread into the single
// geometry buffer, so a single voxel edit only re-meshes its own chunk (and the
// adjacent chunk when the edit sits on a chunk face).
namespace VoxelChunk {

// Immutable input handed to a worker. colors covers the region
// [x0-1 .. x0+sizeX] x [y0-1 .. y0+sizeY] x [z0-1 .. z0+sizeZ], i.e. the chunk
// plus a one-voxel border, stored as ARGB values (0 == empty). Coordinates are
// global voxel coordinates so world positions match the non-chunked layout.
struct MeshInput {
    int chunkId = -1;
    int x0 = 0, y0 = 0, z0 = 0;         // chunk origin in global voxel coords
    int sizeX = 0, sizeY = 0, sizeZ = 0; // chunk extent (clamped at volume edges)
    QVector<QRgb> colors;               // (sizeX+2)*(sizeY+2)*(sizeZ+2)
    float voxelSize = 1.0f;
    float spacing = 0.0f;
    float voxelStep = 1.0f;             // voxelSize + spacing
    float offsetX = 0.0f;               // world-space centring offsets
    float offsetZ = 0.0f;
};

// Meshed output for one chunk. indices are local (0-based within this chunk);
// the main thread rebases them when concatenating chunks.
struct MeshResult {
    int chunkId = -1;
    QByteArray vertices;   // interleaved position(3) + color(4) + normal(3) floats
    QByteArray indices;    // quint32, local 0-based
    int vertexCount = 0;
};

// Runs greedy meshing for a single chunk. Thread-safe / free of Qt object state.
MeshResult buildMesh(const MeshInput &in);

}
