// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef DYNAMICINSTANCING_H
#define DYNAMICINSTANCING_H

#include <QQuick3DInstancing>
#include <QVector3D>
#include <QVector4D>
#include <QVariantList>
#include <QByteArray>
#include <QColor>
#include <QList>

// General-purpose dynamic instance table for animated fleets of identical
// meshes (cars, crowds, projectiles). Per-entry statics (scale, color, custom
// data) are set once via setBulk(); per-frame movement is pushed through
// updatePoses() from a packed float32 buffer, so the hot path costs no QObject
// property writes and no full CPU table rebuild. Mirrors LineBatchInstancing's
// 80-byte-entry / dynamic-buffer / markDirty architecture. Exposed to QML as
// DynamicInstances3D.
class DynamicInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_NAMED_ELEMENT(DynamicInstances3D)

    Q_PROPERTY(int capacity READ capacity WRITE setCapacity NOTIFY capacityChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // Read-only diagnostics (see PerfRegistry / PerfHud).
    Q_PROPERTY(int bytesLastUpload READ bytesLastUpload NOTIFY statsChanged)
    Q_PROPERTY(double packMsLast READ packMsLast NOTIFY statsChanged)
    Q_PROPERTY(double uploadsPerSecond READ uploadsPerSecond NOTIFY statsChanged)

public:
    explicit DynamicInstancing(QQuick3DObject *parent = nullptr);

    int capacity() const;
    void setCapacity(int capacity);

    int count() const;

    int bytesLastUpload() const;
    double packMsLast() const;
    double uploadsPerSecond() const;

    // One-time / rare setup of per-entry statics. scales holds one vector3d per
    // entry, colors one color per entry, customData an optional vec4 per entry.
    // Sets count to the number of entries and (auto-grows) capacity to fit.
    Q_INVOKABLE void setBulk(const QVariantList &scales,
                             const QVariantList &colors,
                             const QVariantList &customData = QVariantList());

    // THE hot path: packed float32 [x, y, z, yawRad] per entry, starting at
    // entry `first`. The rotation rows are built from yaw combined with the
    // stored per-entry scale and written straight into the table.
    Q_INVOKABLE void updatePoses(int first, const QByteArray &poses);

    // Occasional per-entry color change (e.g. state highlight).
    Q_INVOKABLE void setEntryColor(int i, const QColor &c);

    // Explicit culling / shadow bounds so Qt skips the O(n) per-upload bounds
    // recomputation when the host already knows the roaming volume.
    Q_INVOKABLE void setExtents(const QVector3D &min, const QVector3D &max);

signals:
    void capacityChanged();
    void countChanged();
    void statsChanged();

protected:
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    void ensureCapacity(int n);
    void writeEntry(char *dst, int index, float x, float y, float z, float yaw) const;
    void noteUpload();

    QByteArray m_data;                 // capacity * 80 bytes
    QList<QVector3D> m_scales;         // per-entry scale
    QList<QVector4D> m_colors;         // per-entry rgba (0..1)
    QList<QVector4D> m_customData;     // per-entry custom vec4
    int m_capacity = 0;
    int m_count = 0;
    bool m_dirty = false;

    // diagnostics
    int m_bytesLastUpload = 0;
    double m_packMsLast = 0.0;
    double m_uploadsPerSecond = 0.0;
    QList<qint64> m_uploadStamps;      // recent upload timestamps (ms)
};

#endif // DYNAMICINSTANCING_H
