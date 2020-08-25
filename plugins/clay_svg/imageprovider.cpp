// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#include "imageprovider.h"

#include <QBitmap>
#include <QRegion>
#include <QPainter>
#include <QFile>
#include <QTextStream>
#include <QDebug>
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

QSvgRenderer& ImageProvider::fetchRenderer(const QString& imgId, const QUrlQuery& queryPart)
{
    QString svgDir = ":";
    const auto sbxvar = "CLAYGROUND_SBX_DIR";
    if (qEnvironmentVariableIsSet(sbxvar))
        svgDir = qEnvironmentVariable(sbxvar);

    const auto svgPath = QString(svgDir + "/%1.svg").arg(imgId);
    if (!svgCache_.contains(svgPath)) {
        QFile f(svgPath);
        if (f.open(QFile::ReadOnly | QFile::Text))
        {
            const auto icKey = QString("ignoredColor");
            QString ic;
            if (queryPart.hasQueryItem(icKey))
                ic = QString("#" + queryPart.queryItemValue(icKey));
            QTextStream in(&f);
            QString c = in.readAll();
            if (!ic.isEmpty()) c.replace(ic, "transparent");
            svgCache_[svgPath] = new QSvgRenderer(c.toUtf8());
        }
        else {
            qCritical() << "Unable to open " << svgPath;
        }
    }

    return *svgCache_[svgPath];
}

QPixmap ImageProvider::requestPixmap(const QString &path,
                                     QSize *size,
                                     const QSize &requestedSize)
{
    // TODO Error handling does SVG and part exist?
    // Use error images to indicate errors img/id n/a

    // TODO Involve requested size
    if (requestedSize.width() == 0 || requestedSize.height() == 0)
        return QPixmap();

    QUrlQuery queryPart;

    const auto pathParts = path.split("?");
    if (pathParts.size() != 2)
        qCritical() << "Expected path with query part "
                       "<relative-path>?<query-part>";

    queryPart = QUrlQuery(pathParts[1]);

    const auto id = pathParts[0];
    if (coveredImgs_.contains(id))
        clearCache();
    else
        coveredImgs_.insert(id);

    auto& renderer = fetchRenderer(id, queryPart);
    const auto partId = queryPart.queryItemValue("part");

    auto reqSize = requestedSize;
    if (!reqSize.isValid()) {
        const auto partRect = renderer.boundsOnElement(partId);
        reqSize.setWidth(static_cast<int>(partRect.width()));
        reqSize.setHeight(static_cast<int>(partRect.height()));
    }

    QImage img(reqSize.width(), reqSize.height(), QImage::Format_ARGB32);
    QPainter painter(&img);
    painter.setCompositionMode(QPainter::CompositionMode_Clear);
    painter.fillRect(0, 0, img.width(), img.height(), Qt::transparent);
    painter.setCompositionMode(QPainter::CompositionMode_Source);
    renderer.render(&painter, partId);

    size->setWidth(img.width());
    size->setHeight(img.height());

    return QPixmap::fromImage(img);
}
