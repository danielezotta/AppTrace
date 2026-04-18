#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <chrono>
#include "app_trace_native/app_trace_native_plugin.h"

namespace app_trace_native {

void AppTraceNativePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<AppTraceNativePlugin>();
  plugin->registrar_ = registrar;

  // Create a SHARED method channel that both sides can use
  auto method_channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.apptrace/native",
          &flutter::StandardMethodCodec::GetInstance());

  // Store the channel in the plugin for callbacks
  plugin->method_channel_ = method_channel;

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AppTraceNativePlugin::AppTraceNativePlugin() 
    : activity_monitor_(std::make_unique<ActivityMonitor>()) {}

AppTraceNativePlugin::~AppTraceNativePlugin() {}

void AppTraceNativePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method_name = method_call.method_name();

  if (method_name == "startWindowMonitoring") {
    activity_monitor_->startWindowMonitoring(
        [this](const std::string& process_name, const std::string& executable_path, const std::string& window_title) {
          if (method_channel_) {
            flutter::EncodableMap event_data;
            event_data[flutter::EncodableValue("processName")] =
                flutter::EncodableValue(process_name);
            event_data[flutter::EncodableValue("executablePath")] =
                flutter::EncodableValue(executable_path);
            event_data[flutter::EncodableValue("windowTitle")] =
                flutter::EncodableValue(window_title);
            event_data[flutter::EncodableValue("timestamp")] =
                flutter::EncodableValue(static_cast<int64_t>(
                    std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::system_clock::now().time_since_epoch()
                    ).count()));

            // Send event back to Dart via method call
            method_channel_->InvokeMethod("onActiveWindowChanged",
                std::make_unique<flutter::EncodableValue>(event_data));
          }
        });
    result->Success();
  } else if (method_name == "stopWindowMonitoring") {
    activity_monitor_->stopWindowMonitoring();
    result->Success();
  } else if (method_name == "startInputMonitoring") {
    activity_monitor_->startInputMonitoring(
        [this](int key_count, int mouse_clicks, int mouse_scrolls) {
          if (method_channel_) {
            flutter::EncodableMap event_data;
            event_data[flutter::EncodableValue("keys")] =
                flutter::EncodableValue(key_count);
            event_data[flutter::EncodableValue("mouseClicks")] =
                flutter::EncodableValue(mouse_clicks);
            event_data[flutter::EncodableValue("mouseScrolls")] =
                flutter::EncodableValue(mouse_scrolls);
            event_data[flutter::EncodableValue("timestamp")] =
                flutter::EncodableValue(static_cast<int64_t>(
                    std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::system_clock::now().time_since_epoch()
                    ).count()));

            // Send event back to Dart via method call
            method_channel_->InvokeMethod("onInputCounts",
                std::make_unique<flutter::EncodableValue>(event_data));
          }
        });
    result->Success();
  } else if (method_name == "stopInputMonitoring") {
    activity_monitor_->stopInputMonitoring();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace app_trace_native

void AppTraceNativePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  app_trace_native::AppTraceNativePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
