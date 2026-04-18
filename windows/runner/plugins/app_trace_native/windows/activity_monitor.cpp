#include "include/activity_monitor.h"
#include <psapi.h>
#include <tlhelp32.h>
#include <chrono>

#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "user32.lib")

ActivityMonitor* ActivityMonitor::instance = nullptr;

ActivityMonitor::ActivityMonitor() {
  instance = this;
}

ActivityMonitor::~ActivityMonitor() {
  stopWindowMonitoring();
  stopInputMonitoring();
  instance = nullptr;
}

void ActivityMonitor::startWindowMonitoring(WindowChangeCallback callback) {
  if (windowEventHook != nullptr) return;

  windowCallback = callback;
  windowEventHook = SetWinEventHook(
    EVENT_SYSTEM_FOREGROUND,
    EVENT_SYSTEM_FOREGROUND,
    nullptr,
    windowEventProc,
    0,
    0,
    WINEVENT_OUTOFCONTEXT
  );
}

void ActivityMonitor::stopWindowMonitoring() {
  if (windowEventHook != nullptr) {
    UnhookWinEvent(windowEventHook);
    windowEventHook = nullptr;
  }
}

void CALLBACK ActivityMonitor::windowEventProc(
  HWINEVENTHOOK hWinEventHook,
  DWORD event,
  HWND hwnd,
  LONG idObject,
  LONG idChild,
  DWORD dwEventThread,
  DWORD dwmsEventTime
) {
  if (instance && instance->windowCallback) {
    std::string processName = instance->getActiveProcessName();
    std::string executablePath = instance->getExecutablePath();
    std::string windowTitle = instance->getWindowTitle(hwnd);
    instance->windowCallback(processName, executablePath, windowTitle);
  }
}

void ActivityMonitor::startInputMonitoring(InputCountCallback callback) {
  if (hookThreadRunning) return;

  std::lock_guard<std::mutex> lock(callbackMutex);
  inputCallback = callback;
  keyCount = 0;
  mouseClickCount = 0;
  mouseScrollCount = 0;
  lastReportTime = GetTickCount();

  hookThreadRunning = true;
  
  // Start hooks in a separate thread with message loop
  hookThread = std::make_unique<std::thread>(&ActivityMonitor::hookMessageLoop, this);
  
  // Wait for hooks to be installed
  while (keyboardHook == nullptr && hookThreadRunning) {
    Sleep(10);
  }
}

void ActivityMonitor::hookMessageLoop() {
  hookThreadId = GetCurrentThreadId();
  
  // Install hooks from this thread
  keyboardHook = SetWindowsHookEx(
    WH_KEYBOARD_LL,
    keyboardProc,
    GetModuleHandle(nullptr),
    0
  );

  mouseHook = SetWindowsHookEx(
    WH_MOUSE_LL,
    mouseProc,
    GetModuleHandle(nullptr),
    0
  );

  if (!keyboardHook || !mouseHook) {
    hookThreadRunning = false;
    return;
  }

  // Run message loop to receive hook events
  MSG msg;
  while (hookThreadRunning && GetMessage(&msg, nullptr, 0, 0)) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }

  // Cleanup
  if (keyboardHook) {
    UnhookWindowsHookEx(keyboardHook);
    keyboardHook = nullptr;
  }
  if (mouseHook) {
    UnhookWindowsHookEx(mouseHook);
    mouseHook = nullptr;
  }
}

void ActivityMonitor::stopInputMonitoring() {
  if (!hookThreadRunning) return;

  hookThreadRunning = false;
  
  // Post quit message to stop the message loop
  if (hookThreadId != 0) {
    PostThreadMessage(hookThreadId, WM_QUIT, 0, 0);
  }
  
  // Wait for thread to finish
  if (hookThread && hookThread->joinable()) {
    hookThread->join();
  }
  
  hookThread.reset();
  hookThreadId = 0;
}

LRESULT CALLBACK ActivityMonitor::keyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode >= 0 && instance) {
    if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {
      instance->keyCount++;

      DWORD currentTime = GetTickCount();
      if (currentTime - instance->lastReportTime >= REPORT_INTERVAL_MS) {
        std::lock_guard<std::mutex> lock(instance->callbackMutex);
        if (instance->inputCallback) {
          int keys = instance->keyCount.exchange(0);
          int clicks = instance->mouseClickCount.exchange(0);
          int scrolls = instance->mouseScrollCount.exchange(0);
          instance->lastReportTime = currentTime;
          instance->inputCallback(keys, clicks, scrolls);
        }
      }
    }
  }
  return CallNextHookEx(nullptr, nCode, wParam, lParam);
}

LRESULT CALLBACK ActivityMonitor::mouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode >= 0 && instance) {
    if (wParam == WM_LBUTTONDOWN || wParam == WM_RBUTTONDOWN || wParam == WM_MBUTTONDOWN) {
      instance->mouseClickCount++;
    } else if (wParam == WM_MOUSEWHEEL || wParam == WM_MOUSEHWHEEL) {
      instance->mouseScrollCount++;
    }

    DWORD currentTime = GetTickCount();
    if (currentTime - instance->lastReportTime >= REPORT_INTERVAL_MS) {
      std::lock_guard<std::mutex> lock(instance->callbackMutex);
      if (instance->inputCallback) {
        int keys = instance->keyCount.exchange(0);
        int clicks = instance->mouseClickCount.exchange(0);
        int scrolls = instance->mouseScrollCount.exchange(0);
        instance->lastReportTime = currentTime;
        instance->inputCallback(keys, clicks, scrolls);
      }
    }
  }
  return CallNextHookEx(nullptr, nCode, wParam, lParam);
}

std::string ActivityMonitor::getActiveProcessName() {
  HWND hwnd = GetForegroundWindow();
  if (hwnd == nullptr) return "unknown";

  DWORD processId = 0;
  GetWindowThreadProcessId(hwnd, &processId);

  HANDLE processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
  if (processHandle == nullptr) return "unknown";

  char processName[MAX_PATH] = {0};
  if (GetModuleBaseNameA(processHandle, nullptr, processName, sizeof(processName))) {
    CloseHandle(processHandle);
    return std::string(processName);
  }

  CloseHandle(processHandle);

  // Fallback: extract process name from executable path
  std::string exePath = getExecutablePath();
  if (!exePath.empty()) {
    size_t lastSlash = exePath.find_last_of("\\/");
    if (lastSlash != std::string::npos) {
      return exePath.substr(lastSlash + 1);
    }
    return exePath;
  }

  return "unknown";
}

std::string ActivityMonitor::getExecutablePath() {
  HWND hwnd = GetForegroundWindow();
  if (hwnd == nullptr) return "";

  DWORD processId = 0;
  GetWindowThreadProcessId(hwnd, &processId);

  HANDLE processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
  if (processHandle == nullptr) return "";

  char executablePath[MAX_PATH] = {0};
  if (GetModuleFileNameExA(processHandle, nullptr, executablePath, sizeof(executablePath))) {
    CloseHandle(processHandle);
    return std::string(executablePath);
  }

  CloseHandle(processHandle);
  return "";
}

std::string ActivityMonitor::getWindowTitle(HWND hwnd) {
  if (hwnd == nullptr) return "";

  int length = GetWindowTextLength(hwnd);
  if (length == 0) return "";

  char title[256] = {0};
  GetWindowTextA(hwnd, title, sizeof(title) - 1);
  return std::string(title);
}
