// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#include "imageprovider.h"

#include <QSvgRenderer>
#include <QPainter>
#include <QImage>
#include <QDebug>
#include <math.h>

ImageProvider::ImageProvider(): QQuickImageProvider(QQuickImageProvider::Pixmap)
{ }

QPixmap ImageProvider::requestPixmap(const QString &id,
                                     QSize *size,
                                     const QSize &requestedSize)
{
    // TODO Error handling does SVG and part exist?
    // Use error images to indicate errors img/id n/a

    // TODO Involve requested size

    // TODO Add caching of SVGRenderers

    // TODO Add ignored color as query param - only replace if set

    const auto idParts = id.split("/");
    const auto imgId = idParts.at(0);

    QString svgDir = ":";
    const auto sbxvar = "CLAYGROUND_SBX_DIR";
    if (qEnvironmentVariableIsSet(sbxvar))
        svgDir = qEnvironmentVariable(sbxvar);

    QSvgRenderer renderer(QString(svgDir + "/%1.svg").arg(imgId));

    const auto partId = idParts.at(1);
    auto reqSize = requestedSize;
    if (!reqSize.isValid()) {
        const auto partRect = renderer.boundsOnElement(partId);
        reqSize.setWidth(static_cast<int>(partRect.width()));
        reqSize.setHeight(static_cast<int>(partRect.height()));
    }
    QImage img(reqSize.width(), reqSize.height(), QImage::Format_ARGB32);

    QPainter painter(&img);
    painter.setCompositionMode(QPainter::CompositionMode_Source);
    painter.fillRect(0, 0, img.width(), img.height(), Qt::transparent);
    painter.setCompositionMode(QPainter::CompositionMode_SourceOver);
    renderer.render(&painter, partId);

    size->setWidth(img.width());
    size->setHeight(img.height());

    auto scan = img.scanLine(0);
    auto rgbpixel = reinterpret_cast<QRgb*>(scan);
    auto brder = QColor(*rgbpixel);

    for (int i=0; i<img.height(); ++i) {
        auto scan = img.scanLine(i);
        int depth =4;
        for (int j = 0; j < img.width(); ++j) {
            auto& rgbpixel = *reinterpret_cast<QRgb*>(scan + j*depth);
            if (QColor(rgbpixel) == brder)
                rgbpixel = QColorConstants::Transparent.rgba();
        }
    }

    return QPixmap::fromImage(img);
}
