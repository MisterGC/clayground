// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QRectF>
#include <QString>
#include <QVariantMap>

// The half of an annotation that only a scene query can answer (issue #182):
// what a framed rect is ABOUT, and where that thing is on screen now.
//
// ClayInspector implements it against the live sandbox; ClayAnnotationStore
// calls it. The interface exists so the store keeps working - and stays
// testable - when there is no scene to ask, which is exactly the case in the
// store's own unit tests and before the first load has finished.
class ClayAnchorResolver
{
public:
    virtual ~ClayAnchorResolver() = default;

    // Resolve what `rect` is about and write anchor + crop into the entry with
    // this id. Returns {anchor, crop, ...}; failure is reported in the answer,
    // never by throwing an annotation away.
    virtual QVariantMap attachAnnotation(const QString& id, const QRectF& rect) = 0;

    // Where a stored anchor is NOW: {resolved, x, y, via, insideViewport, ...}.
    virtual QVariantMap reprojectAnchor(const QVariantMap& anchor) const = 0;
};
