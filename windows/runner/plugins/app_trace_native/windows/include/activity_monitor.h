#pragma once

#include <windows.h>
#include <string>
#include <functional>
#include <memory>
#include <thread>
#include <atomic>
#include <mutex>

class ActivityMonitor {
public:
  using WindowChangeCallback = std::function<void(const std::string&, const std::string&, const std::string&)>;
  using InputCountCallback = std::function<void(int, int, int)>;

  ActivityMonitor();
  ~ActivityMonitor();

  void startWindowMonitoring(WindowChangeCallback callback);
  void stopWindowMonitoring();

  void startInputMonitoring(InputCountCallback callback);
  void stopInputMonitoring();

private:
  // Window monitoring
  HWINEVENTHOOK windowEventHook = nullptr;
  WindowChangeCallback windowCallback;
  static void CALLBACK windowEventProc(
    HWINEVENTHOOK hWinEventHook,
    DWORD event,
    HWND hwnd,
    LONG idObject,
    LONG idChild,
    DWORD dwEventThread,
    DWORD dwmsEventTime
  );

  // Input monitoring
  HHOOK keyboardHook = nullptr;
  HHOOK mouseHook = nullptr;
  InputCountCallback inputCallback;
  
  std::atomic<int> keyCount{0};
  std::atomic<int> mouseClickCount{0};
  std::atomic<int> mouseScrollCount{0};
  DWORD lastReportTime = 0;
  static const DWORD REPORT_INTERVAL_MS = 60000; // 1 minute

  // Message loop thread for hooks
  std::unique_ptr<std::thread> hookThread;
  std::atomic<bool> hookThreadRunning{false};
  DWORD hookThreadId = 0;
  std::mutex callbackMutex;

  void hookMessageLoop();
  static LRESULT CALLBACK keyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
  static LRESULT CALLBACK mouseProc(int nCode, WPARAM wParam, LPARAM lParam);

  static ActivityMonitor* instance;
  std::string getActiveProcessName();
  std::string getExecutablePath();
  std::string getWindowTitle(HWND hwnd);
};
