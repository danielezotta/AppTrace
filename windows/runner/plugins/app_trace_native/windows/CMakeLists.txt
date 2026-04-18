cmake_minimum_required(VERSION 3.14)
project(app_trace_native_plugin LANGUAGES CXX)

add_library(app_trace_native_plugin SHARED
  "app_trace_native_plugin.cpp"
  "activity_monitor.cpp"
)

target_include_directories(app_trace_native_plugin PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_compile_features(app_trace_native_plugin PRIVATE cxx_std_17)

set_target_properties(app_trace_native_plugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  WINDOWS_EXPORT_ALL_SYMBOLS ON
)

target_link_libraries(app_trace_native_plugin PRIVATE
  flutter
  flutter_wrapper_plugin
  psapi.lib
  user32.lib
)
