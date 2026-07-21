#ifndef LINESTYLETEXTUREDATA_H
#define LINESTYLETEXTUREDATA_H

#include <QQuick3DTextureData>
#include <QVariantList>

class LineStyleTextureData : public QQuick3DTextureData
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LineStyleTextureData)

    Q_PROPERTY(QVariantList styles READ styles WRITE setStyles NOTIFY stylesChanged)
    Q_PROPERTY(int styleCount READ styleCount NOTIFY stylesChanged)

public:
    // Style-table format version. The texture is kTableRows RGBA32F rows tall;
    // the fragment shader hard-codes the same height, so bumping the format
    // means bumping this constant and the matching literal in line_batch.frag.
    //   row 0: dashLen, gapLen, capRound, opacity        (v1 layout, frozen)
    //   row 1: patternId (glyph enum | screen-units bit), param0 (triangle
    //          base-width fraction), param1, flow
    //   row 2: glow, pulse, headLength, headWidth
    static constexpr int kTableRows = 3;

    explicit LineStyleTextureData(QQuick3DObject *parent = nullptr);

    QVariantList styles() const;
    void setStyles(const QVariantList &styles);

    int styleCount() const;

signals:
    void stylesChanged();

private:
    void rebuild();

    QVariantList m_styles;
    int m_styleCount = 1;
};

#endif // LINESTYLETEXTUREDATA_H
