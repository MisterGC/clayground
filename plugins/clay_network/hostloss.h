// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QString>

// Why a joiner lost its host (#376), shared by the native and the WASM
// backend. A game acts on these codes, never on the message's English text.
namespace clay::network::hostloss {

// The host said goodbye: it called leave()
inline QString hostLeft() { return QStringLiteral("host-left"); }
// The host left its pings unanswered for the grace period: it crashed,
// froze or its link went dark
inline QString hostTimeout() { return QStringLiteral("host-timeout"); }
// The connection to the host closed or failed without a goodbye
inline QString connectionLost() { return QStringLiteral("connection-lost"); }

} // namespace clay::network::hostloss
