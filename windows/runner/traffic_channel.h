#ifndef RUNNER_TRAFFIC_CHANNEL_H_
#define RUNNER_TRAFFIC_CHANNEL_H_

#include <flutter/binary_messenger.h>

// Регистрирует MethodChannel "net_pulse/traffic": метод "getCounters"
// возвращает [totalRx, totalTx] — суммарные байты с момента загрузки ОС.
void RegisterTrafficChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_TRAFFIC_CHANNEL_H_
