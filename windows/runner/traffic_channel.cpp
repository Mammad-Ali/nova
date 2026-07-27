// winsock2.h должен быть подключён до любого заголовка, который может
// затянуть <windows.h> без WIN32_LEAN_AND_MEAN (flutter_window.h делает это
// через win32_window.h) — иначе устаревший <winsock.h>, который тот тянет,
// конфликтует с <winsock2.h>/<iphlpapi.h> ниже. Поэтому канал живёт в своей
// собственной единице трансляции, а не в flutter_window.cpp.
// GetIfTable2/MIB_IF_TABLE2 объявлены в <netioapi.h> под защитой
// `NTDDI_VERSION >= NTDDI_VISTA`. Раннер Flutter версию Windows не задаёт,
// поэтому объявляем её сами ДО системных заголовков — иначе эти символы
// просто не попадут в трансляцию (проверено сборкой на Windows CI).
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00 // Windows 10
#endif
#ifndef NTDDI_VERSION
#define NTDDI_VERSION 0x0A000000 // NTDDI_WIN10
#endif

#include <winsock2.h>
#include <ws2ipdef.h> // SOCKADDR_INET, нужен для типов в netioapi.h
#include <iphlpapi.h>
#include <netioapi.h>

#include "traffic_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <utility>

#pragma comment(lib, "iphlpapi.lib")

namespace {

// Суммирует Rx/Tx октеты по физическим адаптерам, пропуская loopback и
// виртуальные интерфейсы (VPN-туннели и т.п.) — то же правило фильтрации,
// что и в реализациях для macOS/Android.
std::pair<int64_t, int64_t> ReadCounters() {
  int64_t rx = 0;
  int64_t tx = 0;

  PMIB_IF_TABLE2 table = nullptr;
  if (GetIfTable2(&table) == NO_ERROR && table != nullptr) {
    for (ULONG i = 0; i < table->NumEntries; ++i) {
      const MIB_IF_ROW2& row = table->Table[i];
      if (row.Type == IF_TYPE_SOFTWARE_LOOPBACK) continue;
      if (!row.InterfaceAndOperStatusFlags.HardwareInterface) continue;
      rx += static_cast<int64_t>(row.InOctets);
      tx += static_cast<int64_t>(row.OutOctets);
    }
    FreeMibTable(table);
  }

  return {rx, tx};
}

}  // namespace

void RegisterTrafficChannel(flutter::BinaryMessenger* messenger) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "net_pulse/traffic",
          &flutter::StandardMethodCodec::GetInstance());

  // SetMethodCallHandler передаёт обработчик мессенджеру по значению — сам
  // объект channel можно безопасно уничтожить сразу после этого вызова,
  // как и делают официальные плагины Flutter для Windows.
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "getCounters") {
          result->NotImplemented();
          return;
        }
        const auto counters = ReadCounters();
        result->Success(flutter::EncodableValue(flutter::EncodableList{
            flutter::EncodableValue(counters.first),
            flutter::EncodableValue(counters.second),
        }));
      });
}
