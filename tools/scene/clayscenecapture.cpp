// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayscenecapture.h"
#include "clayscenehost.h"

#include <QDir>
#include <QFileInfo>
#include <QSaveFile>
#include <QtMath>

namespace ClayScene {

CaptureResult capture(const Host& host, const CaptureRequest& request)
{
    CaptureResult result;

    QString grabError;
    QImage image = host.grabImage(request.timeoutMs, &grabError);
    if (image.isNull()) {
        result.error = grabError.isEmpty()
                       ? QStringLiteral("capture failed") : grabError;
        return result;
    }

    if (!request.crop.isNull()) {
        QRect clipped = request.crop.intersected(image.rect());
        if (clipped.isEmpty()) {
            result.error = QStringLiteral(
                "crop %1,%2 %3x%4 lies outside the %5x%6 viewport")
                .arg(request.crop.x()).arg(request.crop.y())
                .arg(request.crop.width()).arg(request.crop.height())
                .arg(image.width()).arg(image.height());
            return result;
        }
        image = image.copy(clipped);
    }

    int targetWidth = 0;
    if (request.targetWidth > 0)
        targetWidth = request.targetWidth;
    else if (request.scale > 0.0 && !qFuzzyCompare(request.scale, 1.0))
        targetWidth = qMax(1, qRound(image.width() * request.scale));

    if (targetWidth > 0 && targetWidth != image.width())
        image = image.scaledToWidth(targetWidth, Qt::SmoothTransformation);

    result.image = image;
    return result;
}

bool saveImage(const QImage& image, const QString& path, QString* error)
{
    if (image.isNull()) {
        if (error) *error = QStringLiteral("nothing to save (null image)");
        return false;
    }

    QDir parent = QFileInfo(path).absoluteDir();
    if (!parent.exists() && !parent.mkpath(".")) {
        if (error) *error = QStringLiteral("cannot create %1").arg(parent.path());
        return false;
    }

    // Atomic: a reader polling for the file never sees a half-written PNG.
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error) *error = QStringLiteral("cannot open %1").arg(path);
        return false;
    }
    if (!image.save(&file, "PNG")) {
        if (error) *error = QStringLiteral("PNG encoding failed for %1").arg(path);
        return false;
    }
    if (!file.commit()) {
        if (error) *error = QStringLiteral("cannot commit %1").arg(path);
        return false;
    }
    return true;
}

DiffResult diffImages(const QImage& a, const QImage& b, int tolerance)
{
    DiffResult result;

    if (a.isNull() || b.isNull()) {
        result.error = QStringLiteral("diff needs two images");
        return result;
    }
    if (a.size() != b.size()) {
        result.error = QStringLiteral("size mismatch: %1x%2 vs %3x%4")
                       .arg(a.width()).arg(a.height())
                       .arg(b.width()).arg(b.height());
        return result;
    }

    const QImage left = a.convertToFormat(QImage::Format_ARGB32);
    const QImage right = b.convertToFormat(QImage::Format_ARGB32);

    int minX = left.width(), minY = left.height(), maxX = -1, maxY = -1;
    qint64 changed = 0;

    for (int y = 0; y < left.height(); ++y) {
        const auto* lp = reinterpret_cast<const QRgb*>(left.constScanLine(y));
        const auto* rp = reinterpret_cast<const QRgb*>(right.constScanLine(y));
        for (int x = 0; x < left.width(); ++x) {
            const QRgb l = lp[x];
            const QRgb r = rp[x];
            int d = qMax(qMax(qAbs(qRed(l) - qRed(r)), qAbs(qGreen(l) - qGreen(r))),
                         qMax(qAbs(qBlue(l) - qBlue(r)), qAbs(qAlpha(l) - qAlpha(r))));
            if (d > tolerance) {
                ++changed;
                minX = qMin(minX, x); maxX = qMax(maxX, x);
                minY = qMin(minY, y); maxY = qMax(maxY, y);
            }
        }
    }

    result.changedPixels = static_cast<int>(changed);
    const qint64 total = static_cast<qint64>(left.width()) * left.height();
    result.delta = total > 0 ? static_cast<double>(changed) / total : 0.0;
    if (maxX >= 0)
        result.changedBounds = QRect(QPoint(minX, minY), QPoint(maxX, maxY));
    return result;
}

} // namespace ClayScene
