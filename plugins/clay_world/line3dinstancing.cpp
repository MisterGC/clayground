#include "line3dinstancing.h"
#include <QVector3D>
#include <QMatrix4x4>


LineInstancing::LineInstancing(QQuick3DObject *parent)
    : QQuick3DInstancing(parent)
    , m_width(0.1f)
    , m_color(Qt::blue)
    , m_dirty(true)
{
}

QList<QVector3D> LineInstancing::positions() const
{
    return m_positions;
}

void LineInstancing::setPositions(const QList<QVector3D> &positions)
{
    if (m_positions != positions) {
        m_positions = positions;
        m_dirty = true;
        emit positionsChanged();
        markDirty();
    }
}

float LineInstancing::width() const
{
    return m_width;
}

void LineInstancing::setWidth(float width)
{
    if (!qFuzzyCompare(m_width, width)) {
        m_width = width;
        m_dirty = true;
        emit widthChanged();
        markDirty();
    }
}

QColor LineInstancing::color() const
{
    return m_color;
}

void LineInstancing::setColor(const QColor &color)
{
    if (m_color != color) {
        m_color = color;
        m_dirty = true;
        emit colorChanged();
        markDirty();
    }
}

QByteArray LineInstancing::getInstanceBuffer(int *instanceCount)
{
    if (m_dirty) {
        updateInstanceData();
    }
    *instanceCount = (m_positions.size() > 1) ? (m_positions.size() - 1) : 0;
    return m_instanceData;
}

void LineInstancing::updateInstanceData()
{
    m_instanceData.clear();
    if (m_positions.size() < 2) {
        m_dirty = false;
        return;
    }

    for (int i = 0; i < m_positions.size() - 1; ++i) {
        const QVector3D &pos1 = m_positions[i];
        const QVector3D &pos2 = m_positions[i + 1];
        QVector3D midPoint = (pos1 + pos2) * 0.5f;
        QVector3D direction = pos2 - pos1;
        float length = direction.length();
        direction.normalize();


        QVector3D defaultForward(0, 0, 1);  // Default forward direction (z-axis)
        QQuaternion rotationQuat = QQuaternion::rotationTo(defaultForward, direction);
        QVector3D scale(m_width, m_width, length);

        auto entry = calculateTableEntryFromQuaternion(
            midPoint,
            scale,
            rotationQuat,
            m_color
        );

        m_instanceData.append(reinterpret_cast<const char*>(&entry), sizeof(entry));
    }

    m_dirty = false;
}
