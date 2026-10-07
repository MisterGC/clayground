// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJSValue>
#include <QJSValueIterator>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

// A value from QML as plain maps, lists, numbers and strings, shared by the
// native and the WASM backend. A JS object or array passed to a QVariant
// parameter arrives as a QJSValue, and QJsonValue::fromVariant makes that
// null: a session property holding one reached every joiner as null (#375).
namespace clay::network {

// Deeper than this, a value is cut to null: a cycle must not hang the caller
constexpr int kPlainDepth = 32;

inline QVariant plainVariant(const QVariant &value, int depth = 0);

inline QVariant plainVariant(const QJSValue &js, int depth)
{
    if (depth > kPlainDepth)
        return {};
    if (js.isArray()) {
        QVariantList out;
        const int n = js.property(QStringLiteral("length")).toInt();
        out.reserve(n);
        for (int i = 0; i < n; ++i)
            out.append(plainVariant(js.property(quint32(i)), depth + 1));
        return out;
    }
    if (js.isObject() && !js.isQObject() && !js.isCallable() && !js.isDate()
        && !js.isRegExp()) {
        QVariantMap out;
        QJSValueIterator it(js);
        while (it.hasNext()) {
            it.next();
            out.insert(it.name(), plainVariant(it.value(), depth + 1));
        }
        return out;
    }
    return js.toVariant(QJSValue::RetainJSObjects);
}

inline QVariant plainVariant(const QVariant &value, int depth)
{
    if (depth > kPlainDepth)
        return {};
    if (value.metaType() == QMetaType::fromType<QJSValue>())
        return plainVariant(value.value<QJSValue>(), depth);
    if (value.metaType() == QMetaType::fromType<QVariantMap>()) {
        QVariantMap out = value.toMap();
        for (auto it = out.begin(); it != out.end(); ++it)
            *it = plainVariant(*it, depth + 1);
        return out;
    }
    if (value.metaType() == QMetaType::fromType<QVariantList>()) {
        QVariantList out = value.toList();
        for (auto &v : out)
            v = plainVariant(v, depth + 1);
        return out;
    }
    return value;
}

} // namespace clay::network
