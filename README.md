# AppTrace

A Flutter desktop app that tracks your activity: which apps you use, for how long, and input counts (keys, clicks, scrolls). Privacy-first with local SQLite storage and CSV export.

## Features
- Active app tracking (process name, window title, duration)
- Keyboard and mouse activity counting (no content by default)
- Daily timeline and top apps dashboard
- CSV export for reports
- Pause/resume and app exclusions
- Tray icon controls

## Tech Stack
- Flutter desktop (UI)
- Native plugin (window hooks, input hooks)
- SQLite (local storage)

## Build
```bash
flutter run -d windows          # Debug (Windows)
flutter build windows           # Release EXE
```

Output: `build\windows\runner\Release\`

## Prerequisites
- Flutter SDK with desktop enabled
- Platform-specific build tools (VS 2022 for Windows, etc.)

## License
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
