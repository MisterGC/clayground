// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#include "imageprovider.h"

#include <QPainter>
#include <math.h>

ImageProvider::ImageProvider(): QQuickImageProvider(QQuickImageProvider::Pixmap)
{ }

ImageProvider::~ImageProvider()
{
    clearCache();
}

void ImageProvider::clearCache()
{
    qDeleteAll(svgCache_);
    svgCache_.clear();
}

QSvgRenderer& ImageProvider::fetchRenderer(const QString& imgId)
{
    QString svgDir = ":";
    const auto sbxvar = "CLAYGROUND_SBX_DIR";
    if (qEnvironmentVariableIsSet(sbxvar))
        svgDir = qEnvironmentVariable(sbxvar);

    const auto svgPath = QString(svgDir + "/%1.svg").arg(imgId);
    if (!svgCache_.contains(svgPath)) {
        svgCache_[svgPath] = new QSvgRenderer(svgPath);
    }
    return *svgCache_[svgPath];
}

void ImageProvider::hideIgnoredColor(const QUrlQuery& queryPart, QImage& img)
{
    const auto ignoredColorKey = QString("ignoredColor");
    QColor ignoredColor;

    if (queryPart.hasQueryItem(ignoredColorKey))
        ignoredColor = QColor("#" + queryPart.queryItemValue(ignoredColorKey));

    if (ignoredColor.isValid())
    {
        for (int i=0; i<img.height(); ++i) {
            auto scan = img.scanLine(i);
            int depth =4;
            for (int j = 0; j < img.width(); ++j) {
                auto& rgbpixel = *reinterpret_cast<QRgb*>(scan + j*depth);
                if (QColor(rgbpixel) == ignoredColor)
                    rgbpixel = QColorConstants::Transparent.rgba();
            }
        }
    }

}

QPixmap ImageProvider::requestPixmap(const QString &path,
                                     QSize *size,
                                     const QSize &requestedSize)
{
    // TODO Error handling does SVG and part exist?
    // Use error images to indicate errors img/id n/a

    // TODO Involve requested size

    QUrlQuery queryPart;

    const auto pathParts = path.split("?");
    if (pathParts.size() > 1) {
        // TODO error msg if not exactly two parts
        queryPart = QUrlQuery(pathParts[1]);
    }

    const auto id = pathParts[0];
    if (coveredImgs_.contains(id))
        clearCache();
    else
        coveredImgs_.insert(id);
    const auto idParts = id.split("/");

    const auto imgId = idParts.at(0);
    auto& renderer = fetchRenderer(imgId);

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

    hideIgnoredColor(queryPart, img);

    return QPixmap::fromImage(img);
}
