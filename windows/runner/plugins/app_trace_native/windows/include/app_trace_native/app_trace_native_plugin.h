#ifndef FLUTTER_PLUGIN_APP_TRACE_NATIVE_PLUGIN_H_
#define FLUTTER_PLUGIN_APP_TRACE_NATIVE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include "activity_monitor.h"

namespace app_trace_native {

class AppTraceNativePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  AppTraceNativePlugin();

  virtual ~AppTraceNativePlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
          result);

  // Activity monitor instance
  std::unique_ptr<ActivityMonitor> activity_monitor_;

  // Shared method channel for bidirectional communication
  std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

  // Registrar for accessing the binary messenger
  flutter::PluginRegistrarWindows* registrar_;
};

}  // namespace app_trace_native

void AppTraceNativePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#endif  // FLUTTER_PLUGIN_APP_TRACE_NATIVE_PLUGIN_H_
