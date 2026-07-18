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
