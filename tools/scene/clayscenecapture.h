// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QImage>
#include <QRect>
#include <QString>

namespace ClayScene {

class Host;

// A capture request as an agent expresses it: render, cut out the region that
// matters, scale it down to something readable. Crop is applied before scale.
struct CaptureRequest
{
    QRect crop;              // null rect => the whole viewport
    double scale = 1.0;      // <= 0 or 1.0 => no scaling
    int targetWidth = 0;     // > 0 wins over scale
    int timeoutMs = 3000;
};

struct CaptureResult
{
    QImage image;
    QString error;
    bool ok() const { return !image.isNull() && error.isEmpty(); }
};

// Renders through the host and applies crop/scale. A crop that does not
// intersect the rendered image is an error, never a silent clamp - a picture
// of the wrong thing is worse than no picture.
CaptureResult capture(const Host& host, const CaptureRequest& request = {});

// Writes a PNG, creating parent directories as needed.
bool saveImage(const QImage& image, const QString& path, QString* error = nullptr);

struct DiffResult
{
    double delta = 0.0;      // fraction of pixels beyond tolerance (0..1)
    int changedPixels = 0;
    QRect changedBounds;     // null when nothing changed
    QString error;
    bool ok() const { return error.isEmpty(); }
};

// Per-pixel comparison of two captures of the same size. 'tolerance' is the
// maximum per-channel difference still counted as equal, which absorbs the
// small variation between two runs of the same GPU scene.
DiffResult diffImages(const QImage& a, const QImage& b, int tolerance = 0);

} // namespace ClayScene
