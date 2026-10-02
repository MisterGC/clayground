// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

// Test-only hooks into libdatachannel's callbacks. A callback that reaches an
// object after it is destroyed (#357, #359) does so only in a narrow window;
// a test holds a close callback here, on libdatachannel's thread, before it
// touches its object, and destroys the object meanwhile. Compiled in only
// where CLAY_NETWORK_TEST_HOOKS is defined - the tests that need it; the
// plugin itself never has them.

#ifdef CLAY_NETWORK_TEST_HOOKS

#include <atomic>

namespace clay::network::testhooks {

// Called with the object a close callback is about to reach, on the thread
// libdatachannel reports the close on. Null = no hook.
inline std::atomic<void (*)(const void *owner)> closeCallback{nullptr};

} // namespace clay::network::testhooks

#define CLAY_NETWORK_CLOSE_HOOK(owner) \
    do { \
        if (auto hook = clay::network::testhooks::closeCallback.load()) \
            hook(owner); \
    } while (false)

#else

#define CLAY_NETWORK_CLOSE_HOOK(owner) do { } while (false)

#endif
