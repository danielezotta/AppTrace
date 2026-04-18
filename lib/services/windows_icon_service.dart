import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';

const int _maxCacheSize = 100;

/// Extracts Windows application icons via Win32 APIs and caches them in
/// memory. Returns `null` when extraction fails, so callers can fall back to
/// Material icons.
class WindowsIconService {
  static final WindowsIconService _instance = WindowsIconService._internal();

  final LinkedHashMap<String, ImageProvider> _iconCache =
      LinkedHashMap<String, ImageProvider>();
  final LinkedHashMap<String, bool> _failedCache =
      LinkedHashMap<String, bool>();

  factory WindowsIconService() => _instance;
  WindowsIconService._internal();

  Future<ImageProvider?> getImageForExecutable(String executablePath) async {
    if (executablePath.isEmpty) return null;
    if (!Platform.isWindows) return null;

    final cached = _iconCache.remove(executablePath);
    if (cached != null) {
      _iconCache[executablePath] = cached; // touch LRU
      return cached;
    }
    if (_failedCache.containsKey(executablePath)) return null;

    try {
      final bytes = await _extractIconPngBytes(executablePath);
      if (bytes == null) {
        _rememberFailure(executablePath);
        return null;
      }
      final provider = MemoryImage(bytes);
      _rememberSuccess(executablePath, provider);
      return provider;
    } catch (_) {
      _rememberFailure(executablePath);
      return null;
    }
  }

  void _rememberSuccess(String key, ImageProvider value) {
    _iconCache[key] = value;
    while (_iconCache.length > _maxCacheSize) {
      _iconCache.remove(_iconCache.keys.first);
    }
  }

  void _rememberFailure(String key) {
    _failedCache[key] = true;
    while (_failedCache.length > _maxCacheSize) {
      _failedCache.remove(_failedCache.keys.first);
    }
  }

  void clearCaches() {
    _iconCache.clear();
    _failedCache.clear();
  }
}

/// Extracts a 32x32 icon from [executablePath] and returns PNG-encoded bytes,
/// or `null` on failure.
Future<Uint8List?> _extractIconPngBytes(String executablePath) async {
  final raw = _extractIconRgba(executablePath);
  if (raw == null) return null;
  final (bytes, width, height) = raw;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final pngData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (pngData == null) return null;
    return pngData.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Uses `SHGetFileInfo` + GDI to render the executable's large icon into a
/// top-down 32-bit DIB and returns its RGBA bytes.
(Uint8List, int, int)? _extractIconRgba(String executablePath) {
  // DrawIcon renders at SM_CXICON × SM_CYICON, which can be 48/64 on HiDPI.
  // Size our DIB accordingly so the whole icon fits.
  final int cx = GetSystemMetrics(SM_CXICON);
  final int cy = GetSystemMetrics(SM_CYICON);
  final int iconSize = (cx > 0 && cy > 0) ? (cx > cy ? cx : cy) : 32;

  final pathPtr = executablePath.toNativeUtf16();
  final psfi = calloc<SHFILEINFO>();
  HICON? hIcon;

  try {
    final ok = SHGetFileInfo(
      PCWSTR(pathPtr),
      const FILE_FLAGS_AND_ATTRIBUTES(0),
      psfi,
      sizeOf<SHFILEINFO>(),
      SHGFI_FLAGS(SHGFI_ICON | SHGFI_LARGEICON),
    );
    if (ok == 0) return null;

    final icon = psfi.ref.hIcon;
    if (icon.address == 0) return null;
    hIcon = icon;

    final screenDC = GetDC(null);
    if (screenDC.address == 0) return null;
    final memDC = CreateCompatibleDC(screenDC);
    if (memDC.address == 0) {
      ReleaseDC(null, screenDC);
      return null;
    }

    final bmi = calloc<BITMAPINFO>();
    bmi.ref.bmiHeader
      ..biSize = sizeOf<BITMAPINFOHEADER>()
      ..biWidth = iconSize
      ..biHeight = -iconSize // top-down
      ..biPlanes = 1
      ..biBitCount = 32
      ..biCompression = BI_RGB;

    final ppvBits = calloc<Pointer<Void>>();
    final createResult = CreateDIBSection(
      screenDC,
      bmi,
      DIB_RGB_COLORS,
      ppvBits,
      null,
      0,
    );
    final hBitmap = createResult.value;

    Uint8List? rgba;
    if (hBitmap.address != 0 && ppvBits.value != nullptr) {
      final oldBmp = SelectObject(memDC, HGDIOBJ(hBitmap));
      final drew = DrawIcon(memDC, 0, 0, hIcon);
      if (drew.value) {
        final pixelCount = iconSize * iconSize * 4;
        final bgra = ppvBits.value.cast<Uint8>().asTypedList(pixelCount);
        final out = Uint8List(pixelCount);
        var hasPixel = false;
        for (var i = 0; i < pixelCount; i += 4) {
          out[i] = bgra[i + 2];
          out[i + 1] = bgra[i + 1];
          out[i + 2] = bgra[i];
          out[i + 3] = bgra[i + 3];
          if (out[i + 3] != 0) hasPixel = true;
        }
        if (hasPixel) rgba = out;
      }
      SelectObject(memDC, oldBmp);
      DeleteObject(HGDIOBJ(hBitmap));
    }

    DeleteDC(memDC);
    ReleaseDC(null, screenDC);
    calloc.free(bmi);
    calloc.free(ppvBits);

    if (rgba == null) return null;
    return (rgba, iconSize, iconSize);
  } finally {
    if (hIcon != null) DestroyIcon(hIcon);
    calloc.free(psfi);
    calloc.free(pathPtr);
  }
}
