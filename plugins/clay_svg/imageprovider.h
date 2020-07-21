// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#ifndef CLAYIMAGEPROVIDER_H
#define CLAYIMAGEPROVIDER_H

#include <QQuickImageProvider>
#include <QSvgRenderer>
#include <QHash>
#include <QSet>
#include <QImage>
#include <QUrlQuery>
#include <QSet>

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
    QSvgRenderer &fetchRenderer(const QString& imgId, const QUrlQuery& queryPart);
    void clearCache();

private:
    QHash<QString, QSvgRenderer*> svgCache_;
    QSet<QString> coveredImgs_;
};

#endif // SCALINGIMAGEPROVIDER_H
