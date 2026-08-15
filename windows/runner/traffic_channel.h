#ifndef RUNNER_TRAFFIC_CHANNEL_H_
#define RUNNER_TRAFFIC_CHANNEL_H_

#include <flutter/binary_messenger.h>

// Registers the "net_pulse/traffic" MethodChannel: the "getCounters" method
// returns [totalRx, totalTx] — total bytes since the OS booted.
void RegisterTrafficChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_TRAFFIC_CHANNEL_H_
