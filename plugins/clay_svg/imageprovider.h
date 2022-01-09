// (c) Clayground Contributors - zlib license, see "LICENSE" file
#ifndef CLAYIMAGEPROVIDER_H
#define CLAYIMAGEPROVIDER_H

#include <QQuickImageProvider>
#include <QSvgRenderer>
#include <QHash>
#include <QSet>
#include <QImage>
#include <QUrlQuery>
#include <QSet>

class ImageProvider: public QQuickImageProvider
{
    Q_OBJECT

public:
    ImageProvider();
    virtual ~ImageProvider();
    QPixmap requestPixmap(const QString &path,
                          QSize *size,
                          const QSize &requestedSize) override;
public slots:
    bool exists(const QString& path);

private:
    QSvgRenderer *fetchRenderer(const QString& path, QString &outElId);
    void clearCache();

private:
    QHash<QString, QSvgRenderer*> svgCache_;
    QSet<QString> coveredImgs_;
    bool runsInSbx_ = false;
};

#endif // SCALINGIMAGEPROVIDER_H
