// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "dynamicinstancing.h"
#include <QElapsedTimer>
#include <QDateTime>
#include <cstring>
#include <cmath>

/*!
    \qmltype DynamicInstances3D
    \nativetype DynamicInstancing
    \inqmlmodule Clayground.Canvas3D
    \brief Fast, general-purpose dynamic instance table for animated fleets.

    DynamicInstances3D renders many copies of one base mesh through a single GPU
    instance table whose per-entry transforms are updated every frame from a
    packed binary buffer - no per-instance QObject and no CPU table rebuild on
    the hot path. It is the C++-backed alternative to a declarative
    \c InstanceList of \c InstanceListEntry objects: where an InstanceList pays a
    property write per entry per changed field (and a full table rebuild), this
    type takes one \l updatePoses call per frame carrying every entry's pose.

    Each 80-byte entry stores an affine transform (three vec4 rows, row.w =
    translation), a color and a customData vec4, exactly like the built-in
    instancing. Per-entry statics (scale, color, customData) are set once via
    \l setBulk; movement is pushed each frame via \l updatePoses from a packed
    float32 buffer of \c{[x, y, z, yawRad]} per entry. The transform is
    \c{translate(x,y,z) * rotateY(yaw) * scale}, so the base mesh's local +Z
    axis points along \c yaw.

    Set it as a Model's \c instancing and drive it from a reused \c Float32Array:

    \qml
    import QtQuick
    import QtQuick3D
    import Clayground.Canvas3D

    Model {
        source: "#Cube"
        instancing: DynamicInstances3D {
            id: fleet
            Component.onCompleted: {
                var scales = [], colors = []
                for (var i = 0; i < 500; ++i) {
                    scales.push(Qt.vector3d(0.02, 0.01, 0.03))
                    colors.push("#00d9ff")
                }
                setBulk(scales, colors)
                setExtents(Qt.vector3d(-200, 0, -200), Qt.vector3d(200, 10, 200))
            }
        }
        materials: PrincipledMaterial { lighting: PrincipledMaterial.NoLighting }
    }
    \endqml

    \sa LineBatch3D, PerfRegistry
*/

using Entry = QQuick3DInstancing::InstanceTableEntry;
static constexpr int kEntrySize = sizeof(Entry); // 80 bytes: 5 x vec4

static QVector3D toVector3D(const QVariant &v)
{
    if (v.canConvert<QVector3D>())
        return v.value<QVector3D>();
    const QVariantList l = v.toList();
    if (l.size() >= 3)
        return QVector3D(l.at(0).toFloat(), l.at(1).toFloat(), l.at(2).toFloat());
    return QVector3D(1.0f, 1.0f, 1.0f);
}

static QVector4D colorToVec4(const QVariant &v)
{
    const QColor c = v.value<QColor>();
    if (c.isValid())
        return QVector4D(c.redF(), c.greenF(), c.blueF(), c.alphaF());
    return QVector4D(1.0f, 1.0f, 1.0f, 1.0f);
}

DynamicInstancing::DynamicInstancing(QQuick3DObject *parent)
    : QQuick3DInstancing(parent)
{
}

/*!
    \qmlproperty int DynamicInstances3D::capacity
    \brief Preallocated number of entries the table can hold.

    Growing capacity reallocates the backing buffer; the table never shrinks
    implicitly. \l setBulk auto-grows capacity to fit the entries it is given.
*/
int DynamicInstancing::capacity() const
{
    return m_capacity;
}

void DynamicInstancing::setCapacity(int capacity)
{
    if (capacity <= m_capacity)
        return;
    ensureCapacity(capacity);
    emit capacityChanged();
}

/*!
    \qmlproperty int DynamicInstances3D::count
    \readonly
    \brief Number of active entries currently rendered.
*/
int DynamicInstancing::count() const
{
    return m_count;
}

/*!
    \qmlproperty int DynamicInstances3D::bytesLastUpload
    \readonly
    \brief Size in bytes of the instance data handed to the renderer on the last
    upload (\c{count * 80}).
*/
int DynamicInstancing::bytesLastUpload() const
{
    return m_bytesLastUpload;
}

/*!
    \qmlproperty real DynamicInstances3D::packMsLast
    \readonly
    \brief Wall-clock milliseconds spent packing the last \l updatePoses call.
*/
double DynamicInstancing::packMsLast() const
{
    return m_packMsLast;
}

/*!
    \qmlproperty real DynamicInstances3D::uploadsPerSecond
    \readonly
    \brief Rolling rate of \l updatePoses calls over the last second.
*/
double DynamicInstancing::uploadsPerSecond() const
{
    return m_uploadsPerSecond;
}

void DynamicInstancing::ensureCapacity(int n)
{
    if (n <= m_capacity)
        return;
    m_data.resize(static_cast<qsizetype>(n) * kEntrySize);
    m_scales.reserve(n);
    m_colors.reserve(n);
    m_customData.reserve(n);
    m_capacity = n;
}

/*!
    \qmlmethod void DynamicInstances3D::setBulk(list scales, list colors, list customData)
    \brief Sets the per-entry statics (rare / setup path).

    \a scales holds one vector3d per entry, \a colors one color per entry and
    \a customData an optional vec4 per entry. \l count becomes the number of
    entries and capacity auto-grows to fit. Existing poses are preserved for
    entries that stay in range; new entries start at the origin until the next
    \l updatePoses.
*/
void DynamicInstancing::setBulk(const QVariantList &scales,
                                const QVariantList &colors,
                                const QVariantList &customData)
{
    const int n = static_cast<int>(scales.size());
    ensureCapacity(n);

    m_scales.resize(n);
    m_colors.resize(n);
    m_customData.resize(n);

    const int numColors = static_cast<int>(colors.size());
    const int numCustom = static_cast<int>(customData.size());

    char *base = m_data.data();
    for (int i = 0; i < n; ++i) {
        m_scales[i] = toVector3D(scales.at(i));
        m_colors[i] = (i < numColors) ? colorToVec4(colors.at(i))
                                       : QVector4D(1.0f, 1.0f, 1.0f, 1.0f);
        m_customData[i] = (i < numCustom) ? customData.at(i).value<QVector4D>()
                                          : QVector4D(0.0f, 0.0f, 0.0f, 0.0f);
        // Seed a valid transform at the origin so entries not yet posed do not
        // render as a degenerate (zero) matrix for their first frame.
        if (i >= m_count)
            writeEntry(base, i, 0.0f, 0.0f, 0.0f, 0.0f);
        else {
            // Refresh color/custom of an already-posed entry in place.
            Entry *e = reinterpret_cast<Entry *>(base + static_cast<qsizetype>(i) * kEntrySize);
            e->color = m_colors[i];
            e->instanceData = m_customData[i];
        }
    }

    const int prev = m_count;
    m_count = n;
    m_dirty = true;
    markDirty();
    if (m_count != prev)
        emit countChanged();
}

/*!
    \qmlmethod void DynamicInstances3D::updatePoses(int first, ByteArray poses)
    \brief Hot path: rewrites entry poses from a packed float32 buffer.

    \a poses is packed \c{[x, y, z, yawRad]} (four float32) per entry, applied
    to entries starting at index \a first. Each entry's transform is rebuilt
    from its stored scale and the given yaw and written straight into the table
    before a single upload is triggered. Entries beyond \l count (or the current
    \l capacity) are ignored.
*/
void DynamicInstancing::updatePoses(int first, const QByteArray &poses)
{
    if (first < 0 || m_data.isEmpty())
        return;

    QElapsedTimer timer;
    timer.start();

    const int stride = 4; // floats per entry
    const auto *src = reinterpret_cast<const float *>(poses.constData());
    const int available = static_cast<int>(poses.size() / (stride * sizeof(float)));
    const int last = qMin(first + available, qMin(m_count, m_capacity));

    char *base = m_data.data();
    for (int i = first; i < last; ++i) {
        const float *p = src + static_cast<qsizetype>(i - first) * stride;
        writeEntry(base, i, p[0], p[1], p[2], p[3]);
    }

    m_packMsLast = timer.nsecsElapsed() / 1.0e6;
    m_dirty = true;
    markDirty();
    noteUpload();
    emit statsChanged();
}

/*!
    \qmlmethod void DynamicInstances3D::setEntryColor(int i, color c)
    \brief Sets the color of a single entry (occasional path).
*/
void DynamicInstancing::setEntryColor(int i, const QColor &c)
{
    if (i < 0 || i >= m_count || m_data.isEmpty())
        return;
    const QVector4D v(c.redF(), c.greenF(), c.blueF(), c.alphaF());
    m_colors[i] = v;
    Entry *e = reinterpret_cast<Entry *>(m_data.data() + static_cast<qsizetype>(i) * kEntrySize);
    e->color = v;
    m_dirty = true;
    markDirty();
}

/*!
    \qmlmethod void DynamicInstances3D::setExtents(vector3d min, vector3d max)
    \brief Declares the roaming volume so bounds are not recomputed per upload.

    Sets the instancing's shadow bounds to \a min / \a max. When the host knows
    the volume its instances stay inside (e.g. a streamed tile), this skips the
    O(n) per-upload bounds scan Qt otherwise runs over the whole table.
*/
void DynamicInstancing::setExtents(const QVector3D &min, const QVector3D &max)
{
    setShadowBoundsMinimum(min);
    setShadowBoundsMaximum(max);
}

void DynamicInstancing::writeEntry(char *base, int index,
                                   float x, float y, float z, float yaw) const
{
    // Model matrix translate(x,y,z) * rotateY(yaw) * scale, stored row-major as
    // three vec4 rows (row.xyz = matrix row, row.w = translation). rotateY maps
    // local +Z -> (sin yaw, 0, cos yaw), matching an InstanceListEntry with
    // eulerRotation (0, yawDeg, 0), so migrated meshes keep their orientation.
    const QVector3D &s = m_scales.at(index);
    const float c = std::cos(yaw);
    const float sn = std::sin(yaw);

    Entry e;
    e.row0 = QVector4D(s.x() * c, 0.0f, s.z() * sn, x);
    e.row1 = QVector4D(0.0f, s.y(), 0.0f, y);
    e.row2 = QVector4D(-s.x() * sn, 0.0f, s.z() * c, z);
    e.color = m_colors.at(index);
    e.instanceData = m_customData.at(index);

    std::memcpy(base + static_cast<qsizetype>(index) * kEntrySize, &e, kEntrySize);
}

void DynamicInstancing::noteUpload()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    m_uploadStamps.append(now);
    while (!m_uploadStamps.isEmpty() && now - m_uploadStamps.first() > 1000)
        m_uploadStamps.removeFirst();
    m_uploadsPerSecond = m_uploadStamps.size();
}

QByteArray DynamicInstancing::getInstanceBuffer(int *instanceCount)
{
    m_dirty = false;
    if (instanceCount)
        *instanceCount = m_count;
    m_bytesLastUpload = m_count * kEntrySize;
    return m_data;
}
