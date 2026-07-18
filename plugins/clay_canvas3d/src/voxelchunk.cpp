#include "voxelchunk.h"
#include <QVector3D>

namespace VoxelChunk {

namespace {

// Access a voxel in the chunk snapshot. Local coordinates range over
// [-1 .. size] on each axis; the border ring (index -1 and size) holds the
// neighbouring chunk's voxels for cross-chunk face culling.
inline QRgb snapAt(const MeshInput &in, int lx, int ly, int lz)
{
    const int sx = in.sizeX + 2;
    const int sy = in.sizeY + 2;
    return in.colors[(lx + 1) + (ly + 1) * sx + (lz + 1) * sx * sy];
}

inline bool faceVisible(const MeshInput &in, int lx, int ly, int lz, int faceIndex)
{
    int nx = lx, ny = ly, nz = lz;
    switch (faceIndex) {
        case 0: nz--; break; // Front
        case 1: nx++; break; // Right
        case 2: nz++; break; // Back
        case 3: nx--; break; // Left
        case 4: ny++; break; // Top
        case 5: ny--; break; // Bottom
    }
    // Neighbours of an in-chunk voxel always lie inside the bordered snapshot.
    return qAlpha(snapAt(in, nx, ny, nz)) == 0;
}

struct GreedyQuad {
    int x, y, z;        // starting voxel position (local chunk coords)
    int width, height;  // size in voxels on the face's 2D plane
    QRgb color;
    int faceIndex;
};

QVector<GreedyQuad> generateGreedyQuads(const MeshInput &in)
{
    QVector<GreedyQuad> quads;

    for (int faceIndex = 0; faceIndex < 6; ++faceIndex) {
        int axis0, axis1, axis2;
        switch (faceIndex) {
            case 0: // Front (-Z)
            case 2: // Back (+Z)
                axis0 = 0; axis1 = 1; axis2 = 2;
                break;
            case 1: // Right (+X)
            case 3: // Left (-X)
                axis0 = 2; axis1 = 1; axis2 = 0;
                break;
            default: // Top (+Y) / Bottom (-Y)
                axis0 = 0; axis1 = 2; axis2 = 1;
                break;
        }

        const int dim[3] = { in.sizeX, in.sizeY, in.sizeZ };

        for (int slice = 0; slice < dim[axis2]; ++slice) {
            QVector<QRgb> mask(dim[axis0] * dim[axis1], 0);

            for (int a1 = 0; a1 < dim[axis1]; ++a1) {
                for (int a0 = 0; a0 < dim[axis0]; ++a0) {
                    int pos[3];
                    pos[axis0] = a0;
                    pos[axis1] = a1;
                    pos[axis2] = slice;

                    const QRgb voxelColor = snapAt(in, pos[0], pos[1], pos[2]);
                    if (qAlpha(voxelColor) > 0 && faceVisible(in, pos[0], pos[1], pos[2], faceIndex))
                        mask[a0 + a1 * dim[axis0]] = voxelColor;
                }
            }

            QVector<bool> processed(dim[axis0] * dim[axis1], false);

            for (int a1 = 0; a1 < dim[axis1]; ++a1) {
                for (int a0 = 0; a0 < dim[axis0]; ++a0) {
                    const int idx = a0 + a1 * dim[axis0];
                    if (processed[idx] || qAlpha(mask[idx]) == 0) continue;

                    const QRgb quadColor = mask[idx];

                    int quadWidth = 1;
                    while (a0 + quadWidth < dim[axis0]) {
                        const int checkIdx = (a0 + quadWidth) + a1 * dim[axis0];
                        if (processed[checkIdx] || mask[checkIdx] != quadColor) break;
                        quadWidth++;
                    }

                    int quadHeight = 1;
                    bool canExtend = true;
                    while (a1 + quadHeight < dim[axis1] && canExtend) {
                        for (int w = 0; w < quadWidth; ++w) {
                            const int checkIdx = (a0 + w) + (a1 + quadHeight) * dim[axis0];
                            if (processed[checkIdx] || mask[checkIdx] != quadColor) {
                                canExtend = false;
                                break;
                            }
                        }
                        if (canExtend) quadHeight++;
                    }

                    for (int h = 0; h < quadHeight; ++h)
                        for (int w = 0; w < quadWidth; ++w)
                            processed[(a0 + w) + (a1 + h) * dim[axis0]] = true;

                    int pos[3];
                    pos[axis0] = a0;
                    pos[axis1] = a1;
                    pos[axis2] = slice;

                    GreedyQuad quad;
                    quad.x = pos[0];
                    quad.y = pos[1];
                    quad.z = pos[2];
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

} // namespace

MeshResult buildMesh(const MeshInput &in)
{
    MeshResult result;
    result.chunkId = in.chunkId;

    if (in.sizeX <= 0 || in.sizeY <= 0 || in.sizeZ <= 0)
        return result;

    const QVector<GreedyQuad> quads = generateGreedyQuads(in);
    if (quads.isEmpty())
        return result;

    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    vertexBuffer.reserve(quads.size() * 4 * int(sizeof(float)) * 10);
    indexBuffer.reserve(quads.size() * 6 * int(sizeof(quint32)));

    static const QVector3D normals[6] = {
        { 0.0f,  0.0f, -1.0f }, // Front
        { 1.0f,  0.0f,  0.0f }, // Right
        { 0.0f,  0.0f,  1.0f }, // Back
        {-1.0f,  0.0f,  0.0f }, // Left
        { 0.0f,  1.0f,  0.0f }, // Top
        { 0.0f, -1.0f,  0.0f }  // Bottom
    };

    const float voxelStep = in.voxelStep;
    const float voxelSize = in.voxelSize;
    const float spacing = in.spacing;

    int vertexCount = 0;

    for (const GreedyQuad &quad : quads) {
        // World-space position uses global voxel coordinates so chunks line up.
        const float startX = in.offsetX + (in.x0 + quad.x) * voxelStep;
        const float startY = (in.y0 + quad.y) * voxelStep;
        const float startZ = in.offsetZ + (in.z0 + quad.z) * voxelStep;

        float quadWidth, quadHeight, quadDepth;
        QVector3D v0, v1, v2, v3;

        switch (quad.faceIndex) {
            case 0: // Front (-Z)
                quadWidth = quad.width * voxelStep - spacing;
                quadHeight = quad.height * voxelStep - spacing;
                v0 = QVector3D(startX, startY, startZ);
                v1 = QVector3D(startX, startY + quadHeight, startZ);
                v2 = QVector3D(startX + quadWidth, startY + quadHeight, startZ);
                v3 = QVector3D(startX + quadWidth, startY, startZ);
                break;

            case 1: // Right (+X)
                quadDepth = quad.width * voxelStep - spacing;
                quadHeight = quad.height * voxelStep - spacing;
                v0 = QVector3D(startX + voxelSize, startY, startZ);
                v1 = QVector3D(startX + voxelSize, startY + quadHeight, startZ);
                v2 = QVector3D(startX + voxelSize, startY + quadHeight, startZ + quadDepth);
                v3 = QVector3D(startX + voxelSize, startY, startZ + quadDepth);
                break;

            case 2: // Back (+Z)
                quadWidth = quad.width * voxelStep - spacing;
                quadHeight = quad.height * voxelStep - spacing;
                v0 = QVector3D(startX + quadWidth, startY, startZ + voxelSize);
                v1 = QVector3D(startX + quadWidth, startY + quadHeight, startZ + voxelSize);
                v2 = QVector3D(startX, startY + quadHeight, startZ + voxelSize);
                v3 = QVector3D(startX, startY, startZ + voxelSize);
                break;

            case 3: // Left (-X)
                quadDepth = quad.width * voxelStep - spacing;
                quadHeight = quad.height * voxelStep - spacing;
                v0 = QVector3D(startX, startY, startZ + quadDepth);
                v1 = QVector3D(startX, startY + quadHeight, startZ + quadDepth);
                v2 = QVector3D(startX, startY + quadHeight, startZ);
                v3 = QVector3D(startX, startY, startZ);
                break;

            case 4: // Top (+Y)
                quadWidth = quad.width * voxelStep - spacing;
                quadDepth = quad.height * voxelStep - spacing;
                v0 = QVector3D(startX, startY + voxelSize, startZ);
                v1 = QVector3D(startX, startY + voxelSize, startZ + quadDepth);
                v2 = QVector3D(startX + quadWidth, startY + voxelSize, startZ + quadDepth);
                v3 = QVector3D(startX + quadWidth, startY + voxelSize, startZ);
                break;

            default: // Bottom (-Y)
                quadWidth = quad.width * voxelStep - spacing;
                quadDepth = quad.height * voxelStep - spacing;
                v0 = QVector3D(startX, startY, startZ);
                v1 = QVector3D(startX + quadWidth, startY, startZ);
                v2 = QVector3D(startX + quadWidth, startY, startZ + quadDepth);
                v3 = QVector3D(startX, startY, startZ + quadDepth);
                break;
        }

        const float rgba[4] = {
            qRed(quad.color) / 255.0f,
            qGreen(quad.color) / 255.0f,
            qBlue(quad.color) / 255.0f,
            qAlpha(quad.color) / 255.0f
        };

        const QVector3D vertices[4] = { v0, v1, v2, v3 };
        for (const QVector3D &vertex : vertices) {
            vertexBuffer.append(reinterpret_cast<const char *>(&vertex), sizeof(QVector3D));
            vertexBuffer.append(reinterpret_cast<const char *>(rgba), 4 * sizeof(float));
            vertexBuffer.append(reinterpret_cast<const char *>(&normals[quad.faceIndex]), sizeof(QVector3D));
        }

        const quint32 indices[6] = {
            static_cast<quint32>(vertexCount),
            static_cast<quint32>(vertexCount + 1),
            static_cast<quint32>(vertexCount + 2),
            static_cast<quint32>(vertexCount),
            static_cast<quint32>(vertexCount + 2),
            static_cast<quint32>(vertexCount + 3)
        };
        indexBuffer.append(reinterpret_cast<const char *>(indices), 6 * sizeof(quint32));
        vertexCount += 4;
    }

    result.vertices = vertexBuffer;
    result.indices = indexBuffer;
    result.vertexCount = vertexCount;
    return result;
}

} // namespace VoxelChunk
