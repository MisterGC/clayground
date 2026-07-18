#include "linestyletexturedata.h"
#include <QVariantMap>
#include <QVector>
#include <QSize>

/*!
    \qmltype LineStyleTextureData
    \nativetype LineStyleTextureData
    \inqmlmodule Clayground.Canvas3D
    \brief Bakes a list of line styles into a small RGBA32F lookup texture.

    LineStyleTextureData turns the declarative \l{LineBatch3D::styles}{styles}
    list into a one-pixel-tall RGBA32F texture, one texel column per style.
    LineBatch3D's fragment shader samples the column selected by a line's
    \c styleId (carried in the instance table) and decodes it as:

    \list
    \li \c R - dash length in world units (0 = solid)
    \li \c G - gap length in world units
    \li \c B - round-cap flag (1 = round, 0 = square)
    \li \c A - opacity multiplier
    \endlist

    There is always at least one style: index 0 defaults to a solid,
    round-capped, fully opaque line, so \c styleId 0 works without configuring
    any styles.

    This type is used internally by LineBatch3D.

    \sa LineBatch3D
*/
LineStyleTextureData::LineStyleTextureData(QQuick3DObject *parent)
    : QQuick3DTextureData(parent)
{
    rebuild();
}

/*!
    \qmlproperty list LineStyleTextureData::styles
    \brief The declarative list of line styles baked into the texture.

    Each element is an object
    \c{{ dash: [dashLen, gapLen], capRound: <bool>, opacity: <real> }}.
*/
QVariantList LineStyleTextureData::styles() const
{
    return m_styles;
}

void LineStyleTextureData::setStyles(const QVariantList &styles)
{
    m_styles = styles;
    rebuild();
    emit stylesChanged();
}

/*!
    \qmlproperty int LineStyleTextureData::styleCount
    \readonly
    \brief The number of style columns in the texture (always at least 1).
*/
int LineStyleTextureData::styleCount() const
{
    return m_styleCount;
}

void LineStyleTextureData::rebuild()
{
    // Always emit at least one row so that styleId 0 resolves to a sane default
    // (solid, round cap, opaque) even when no styles were configured.
    const int count = qMax(1, static_cast<int>(m_styles.size()));
    m_styleCount = count;

    QVector<float> pixels(count * 4);
    for (int i = 0; i < count; ++i) {
        float dashLen = 0.0f;
        float gapLen = 0.0f;
        float capRound = 1.0f;
        float opacity = 1.0f;

        if (i < m_styles.size()) {
            const QVariantMap m = m_styles.at(i).toMap();
            const QVariantList dash = m.value(QStringLiteral("dash")).toList();
            if (dash.size() >= 2) {
                dashLen = dash.at(0).toFloat();
                gapLen = dash.at(1).toFloat();
            }
            capRound = m.value(QStringLiteral("capRound"), true).toBool() ? 1.0f : 0.0f;
            opacity = m.value(QStringLiteral("opacity"), 1.0).toFloat();
        }

        pixels[i * 4 + 0] = dashLen;
        pixels[i * 4 + 1] = gapLen;
        pixels[i * 4 + 2] = capRound;
        pixels[i * 4 + 3] = opacity;
    }

    QByteArray data(reinterpret_cast<const char *>(pixels.constData()),
                    pixels.size() * static_cast<int>(sizeof(float)));

    setSize(QSize(count, 1));
    setFormat(QQuick3DTextureData::RGBA32F);
    setHasTransparency(true);
    setTextureData(data);
}
