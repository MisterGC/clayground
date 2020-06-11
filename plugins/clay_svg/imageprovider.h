// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#ifndef CLAYIMAGEPROVIDER_H
#define CLAYIMAGEPROVIDER_H

#include <QQuickImageProvider>

class ImageProvider: public QObject, public QQuickImageProvider
{
    Q_OBJECT

public:
    ImageProvider();
    QPixmap requestPixmap(const QString &id,
                          QSize *size,
                          const QSize &requestedSize) override;
};

#endif // SCALINGIMAGEPROVIDER_H
