// winsock2.h must come before any header that might pull in <windows.h>
// without WIN32_LEAN_AND_MEAN (flutter_window.h does exactly that through
// win32_window.h). Otherwise the legacy <winsock.h> it drags in clashes with
// <winsock2.h>/<iphlpapi.h> below. That is why this channel lives in its own
// translation unit rather than inside flutter_window.cpp.
// GetIfTable2/MIB_IF_TABLE2 are declared in <netioapi.h> behind
// `NTDDI_VERSION >= NTDDI_VISTA`. The Flutter runner never sets a Windows
// version, so we declare one ourselves BEFORE the system headers — otherwise
// those symbols never make it into the translation unit (confirmed by CI).
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00 // Windows 10
#endif
#ifndef NTDDI_VERSION
#define NTDDI_VERSION 0x0A000000 // NTDDI_WIN10
#endif

#include <winsock2.h>
#include <ws2ipdef.h> // SOCKADDR_INET, required by types in netioapi.h
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

// Sums Rx/Tx octets across physical adapters, skipping loopback and virtual
// interfaces such as VPN tunnels — the same filtering rule the macOS and
// Android implementations use.
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

  // SetMethodCallHandler hands the callback to the messenger by value, so the
  // channel object itself can be destroyed right after this call — the same
  // pattern the official Flutter Windows plugins use.
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
