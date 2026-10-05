// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <qqmlregistration.h>

// Hands what QML LocalStorage wrote over to the browser's IndexedDB, so it
// survives a page reload (#341). Native builds write straight to disk and
// have nothing to hand over: there persist() does nothing.
class StorageSync : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit StorageSync(QObject* parent = nullptr);

    Q_INVOKABLE void persist();
};
