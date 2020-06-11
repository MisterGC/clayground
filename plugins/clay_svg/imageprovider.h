// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#ifndef CLAYIMAGEPROVIDER_H
#define CLAYIMAGEPROVIDER_H

#include <QQuickImageProvider>
#include <QSvgRenderer>
#include <QHash>
#include <QSet>
#include <QImage>
#include <QUrlQuery>

class ImageProvider: public QObject, public QQuickImageProvider
{
    Q_OBJECT

public:
    ImageProvider();
    virtual ~ImageProvider();
    QPixmap requestPixmap(const QString &path,
                          QSize *size,
                          const QSize &requestedSize) override;
private:
    QSvgRenderer &fetchRenderer(const QString &imgId);
private:
    QHash<QString, QSvgRenderer*> svgCache_;
    void hideIgnoredColor(const QUrlQuery &queryPart, QImage &img);
};

#endif // SCALINGIMAGEPROVIDER_H
