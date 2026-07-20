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
    \c styleId (carried in the instance table) and decodes it. The texture is
    \c kTableRows RGBA32F rows tall (a versioned constant, so adding a row is a
    non-breaking format bump); the rows are:

    \list
    \li \b{row 0} - \c R dash length (0 = solid), \c G gap length,
        \c B round-cap flag (1 = round, 0 = square), \c A opacity multiplier.
        This is the frozen v1 layout: a bare \c{{ dash, capRound, opacity }}
        style leaves rows 1 and 2 all-zero and renders exactly as before.
    \li \b{row 1} - \c R pattern glyph id (0 dash, 1 dot, 2 chevron; bit 8 set
        means the pattern period is measured in screen pixels instead of world
        units), \c G / \c B generic per-glyph params (reserved), \c A flow speed.
    \li \b{row 2} - \c R glow edge softness, \c G pulse depth,
        \c B arrowhead length, \c A arrowhead width (both in line-width units).
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
    \c{{ dash: [dashLen, gapLen], capRound: <bool>, opacity: <real>,
    pattern: <string>, patternUnits: <string>, flow: <real>, glow: <real>,
    pulse: <real>, head: [length, width] }}. All keys past \c opacity are
    optional and default to the plain solid/dashed v1 behaviour.
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
    // Always emit at least one column so that styleId 0 resolves to a sane
    // default (solid, round cap, opaque) even when no styles were configured.
    const int count = qMax(1, static_cast<int>(m_styles.size()));
    m_styleCount = count;

    // Glyph enum, kept in lockstep with line_batch.frag. The screen-units flag
    // rides as bit 8 of the stored id so the glyph itself stays a plain enum.
    constexpr int kGlyphDash = 0;
    constexpr int kGlyphDot = 1;
    constexpr int kGlyphChevron = 2;
    constexpr int kScreenUnitsBit = 8;

    // Row-major RGBA32F: all columns of row 0, then row 1, then row 2.
    QVector<float> pixels(count * 4 * LineStyleTextureData::kTableRows, 0.0f);
    const int rowStride = count * 4;
    for (int i = 0; i < count; ++i) {
        float dashLen = 0.0f;
        float gapLen = 0.0f;
        float capRound = 1.0f;
        float opacity = 1.0f;

        int glyph = kGlyphDash;
        bool screenUnits = false;
        float flow = 0.0f;
        float glow = 0.0f;
        float pulse = 0.0f;
        float headLen = 0.0f;
        float headWid = 0.0f;

        if (i < m_styles.size()) {
            const QVariantMap m = m_styles.at(i).toMap();
            const QVariantList dash = m.value(QStringLiteral("dash")).toList();
            if (dash.size() >= 2) {
                dashLen = dash.at(0).toFloat();
                gapLen = dash.at(1).toFloat();
            }
            capRound = m.value(QStringLiteral("capRound"), true).toBool() ? 1.0f : 0.0f;
            opacity = m.value(QStringLiteral("opacity"), 1.0).toFloat();

            const QString pattern = m.value(QStringLiteral("pattern")).toString().toLower();
            if (pattern == QStringLiteral("dot"))
                glyph = kGlyphDot;
            else if (pattern == QStringLiteral("chevron"))
                glyph = kGlyphChevron;
            // "solid", "dash" and absent all keep the dash glyph (period 0 = solid).

            screenUnits = m.value(QStringLiteral("patternUnits")).toString().toLower()
                          == QStringLiteral("screen");
            flow = m.value(QStringLiteral("flow"), 0.0).toFloat();
            glow = m.value(QStringLiteral("glow"), 0.0).toFloat();
            pulse = m.value(QStringLiteral("pulse"), 0.0).toFloat();

            const QVariantList head = m.value(QStringLiteral("head")).toList();
            if (head.size() >= 2) {
                headLen = head.at(0).toFloat();
                headWid = head.at(1).toFloat();
            }
        }

        const float patternId = static_cast<float>(
            glyph | (screenUnits ? kScreenUnitsBit : 0));

        // row 0
        pixels[0 * rowStride + i * 4 + 0] = dashLen;
        pixels[0 * rowStride + i * 4 + 1] = gapLen;
        pixels[0 * rowStride + i * 4 + 2] = capRound;
        pixels[0 * rowStride + i * 4 + 3] = opacity;
        // row 1
        pixels[1 * rowStride + i * 4 + 0] = patternId;
        pixels[1 * rowStride + i * 4 + 1] = 0.0f; // param0 (reserved)
        pixels[1 * rowStride + i * 4 + 2] = 0.0f; // param1 (reserved)
        pixels[1 * rowStride + i * 4 + 3] = flow;
        // row 2
        pixels[2 * rowStride + i * 4 + 0] = glow;
        pixels[2 * rowStride + i * 4 + 1] = pulse;
        pixels[2 * rowStride + i * 4 + 2] = headLen;
        pixels[2 * rowStride + i * 4 + 3] = headWid;
    }

    QByteArray data(reinterpret_cast<const char *>(pixels.constData()),
                    pixels.size() * static_cast<int>(sizeof(float)));

    setSize(QSize(count, LineStyleTextureData::kTableRows));
    setFormat(QQuick3DTextureData::RGBA32F);
    setHasTransparency(true);
    setTextureData(data);
}
