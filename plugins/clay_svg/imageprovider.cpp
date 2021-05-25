// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#include "imageprovider.h"

#include <QBitmap>
#include <QRegion>
#include <QPainter>
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <math.h>

const auto SBX_DIR_ENV_VAR = "CLAYGROUND_SBX_DIR";

ImageProvider::ImageProvider(): QQuickImageProvider(QQuickImageProvider::Pixmap)
{
    runsInSbx_ = qEnvironmentVariableIsSet(SBX_DIR_ENV_VAR);
}

ImageProvider::~ImageProvider()
{
    clearCache();
}

void ImageProvider::clearCache()
{
    qDeleteAll(svgCache_);
    svgCache_.clear();
}

QSvgRenderer* ImageProvider::fetchRenderer(const QString& path, QString& outElId)
{
    const auto pathParts = path.split("?");
    if (pathParts.size() != 2)
        qCritical() << "Expected path with query part "
                       "<relative-path>?<query-part>";

    auto queryPart = QUrlQuery(pathParts[1]);
    outElId = queryPart.queryItemValue("part");

    const auto id = pathParts[0];
    if (runsInSbx_) {
        if (coveredImgs_.contains(id))
            clearCache();
        else
            coveredImgs_.insert(id);
    }

    QString svgDir = ":";
    if (runsInSbx_)
        svgDir = qEnvironmentVariable(SBX_DIR_ENV_VAR);

    const auto svgPath = QString(svgDir + "/%1.svg").arg(id);
    if (!svgCache_.contains(svgPath)) {
        QFile f(svgPath);
        if (f.open(QFile::ReadOnly | QFile::Text))
        {
            const auto icKey = QString("ignoredColor");
            QString ic;
            if (queryPart.hasQueryItem(icKey))
                ic = QString("#" + queryPart.queryItemValue(icKey));
            QTextStream in(&f);
            auto c = in.readAll();
            if (!ic.isEmpty()) c.replace(ic, "transparent");
            svgCache_[svgPath] = new QSvgRenderer(c.toUtf8());
        }
        else {
            qCritical() << "Unable to open " << svgPath;
            return nullptr;
        }
    }

    return svgCache_[svgPath];
}

QPixmap ImageProvider::requestPixmap(const QString &path,
                                     QSize *size,
                                     const QSize &requestedSize)
{
    // TODO Error handling does SVG and part exist?
    // Use error images to indicate errors img/id n/a

    // TODO Involve requested size
    if (requestedSize.width() == 0 || requestedSize.height() == 0)
        return QPixmap(1,1);

    QString partId;
    auto r = fetchRenderer(path, partId);
    if (!r) return QPixmap(1, 1);
    auto& renderer = *r;

    if (!renderer.elementExists(partId)) {
        qCritical() << "SVG element with id " << partId
                    << "doesn't exist in " << path;
        return QPixmap(1,1);
    }

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

bool ImageProvider::exists(const QString &path)
{
    QString partId;
    auto renderer = fetchRenderer(path, partId);
    if (!renderer) return false;
    return renderer->elementExists(partId);
}
