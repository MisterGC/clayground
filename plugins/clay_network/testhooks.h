// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

// Test-only hooks into libdatachannel's callbacks. A callback that reaches an
// object after it is destroyed (#357, #359) does so only in a narrow window;
// a test holds a close callback here, on libdatachannel's thread, before it
// touches its object, and destroys the object meanwhile. Compiled in only
// where CLAY_NETWORK_TEST_HOOKS is defined - the tests that need it; the
// plugin itself never has them.
//
// A second hook sees every object operation (#306) a node sends to one other
// node, on the Qt thread, and may change it: a test makes the host refuse a
// joiner's spawn that way.

#ifdef CLAY_NETWORK_TEST_HOOKS

#include <atomic>
#include <functional>
#include <QJsonObject>

namespace clay::network::testhooks {

// Called with the object a close callback is about to reach, on the thread
// libdatachannel reports the close on. Null = no hook.
inline std::atomic<void (*)(const void *owner)> closeCallback{nullptr};

// Called with an object operation on its way to one node. Empty = no hook.
inline std::function<void(QJsonObject &op)> objectOp;

} // namespace clay::network::testhooks

#define CLAY_NETWORK_CLOSE_HOOK(owner) \
    do { \
        if (auto hook = clay::network::testhooks::closeCallback.load()) \
            hook(owner); \
    } while (false)

#define CLAY_NETWORK_OBJECT_OP_HOOK(op) \
    do { \
        if (clay::network::testhooks::objectOp) \
            clay::network::testhooks::objectOp(op); \
    } while (false)

#else

#define CLAY_NETWORK_CLOSE_HOOK(owner) do { } while (false)
#define CLAY_NETWORK_OBJECT_OP_HOOK(op) do { } while (false)

#endif
