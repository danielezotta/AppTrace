import 'package:flutter/material.dart';

class IconService {
  static final IconService _instance = IconService._internal();
  final Map<String, IconData> _iconCache = {};
  final Map<String, Color> _colorCache = {};

  factory IconService() {
    return _instance;
  }

  IconService._internal();

  /// Get icon for a process name (e.g., "chrome.exe")
  IconData getIconForProcess(String processName) {
    if (_iconCache.containsKey(processName)) {
      return _iconCache[processName]!;
    }

    final icon = _mapProcessToIcon(processName);
    _iconCache[processName] = icon;
    return icon;
  }

  IconData _mapProcessToIcon(String processName) {
    final lowerName = processName.toLowerCase();

    // Browser icons
    if (lowerName.contains('chrome')) return Icons.language;
    if (lowerName.contains('firefox')) return Icons.language;
    if (lowerName.contains('edge')) return Icons.language;
    if (lowerName.contains('safari')) return Icons.language;
    if (lowerName.contains('opera')) return Icons.language;

    // Development tools
    if (lowerName.contains('vscode') || lowerName.contains('code')) {
      return Icons.code;
    }
    if (lowerName.contains('visual studio') || lowerName.contains('devenv')) {
      return Icons.code;
    }
    if (lowerName.contains('rider')) return Icons.code;
    if (lowerName.contains('intellij')) return Icons.code;
    if (lowerName.contains('sublime')) return Icons.code;
    if (lowerName.contains('notepad')) return Icons.description;

    // Office applications
    if (lowerName.contains('word') || lowerName.contains('winword')) {
      return Icons.description;
    }
    if (lowerName.contains('excel') || lowerName.contains('xlsxe')) {
      return Icons.table_chart;
    }
    if (lowerName.contains('powerpoint') || lowerName.contains('powerpnt')) {
      return Icons.slideshow;
    }
    if (lowerName.contains('outlook')) return Icons.mail;
    if (lowerName.contains('access')) return Icons.storage;

    // Communication
    if (lowerName.contains('slack')) return Icons.chat;
    if (lowerName.contains('discord')) return Icons.chat;
    if (lowerName.contains('telegram')) return Icons.chat;
    if (lowerName.contains('whatsapp')) return Icons.chat;
    if (lowerName.contains('teams')) return Icons.people;
    if (lowerName.contains('zoom')) return Icons.videocam;
    if (lowerName.contains('skype')) return Icons.videocam;

    // Media
    if (lowerName.contains('spotify')) return Icons.music_note;
    if (lowerName.contains('vlc')) return Icons.movie;
    if (lowerName.contains('youtube')) return Icons.play_circle;
    if (lowerName.contains('netflix')) return Icons.play_circle;
    if (lowerName.contains('photoshop')) return Icons.image;
    if (lowerName.contains('premiere')) return Icons.movie;
    if (lowerName.contains('audition')) return Icons.music_note;

    // File management
    if (lowerName.contains('explorer') || lowerName.contains('explorer.exe')) {
      return Icons.folder;
    }
    if (lowerName.contains('7zip') || lowerName.contains('winrar')) {
      return Icons.folder_zip;
    }

    // System
    if (lowerName.contains('settings')) return Icons.settings;
    if (lowerName.contains('task manager') || lowerName.contains('taskmgr')) {
      return Icons.dashboard;
    }
    if (lowerName.contains('cmd') || lowerName.contains('powershell')) {
      return Icons.terminal;
    }
    if (lowerName.contains('regedit')) return Icons.settings;

    // Games
    if (lowerName.contains('steam')) return Icons.sports_esports;
    if (lowerName.contains('epic')) return Icons.sports_esports;
    if (lowerName.contains('game')) return Icons.sports_esports;

    // Default icon
    return Icons.apps;
  }

  /// Get color for a process name
  Color getColorForProcess(String processName) {
    if (_colorCache.containsKey(processName)) {
      return _colorCache[processName]!;
    }

    final color = _mapProcessToColor(processName);
    _colorCache[processName] = color;
    return color;
  }

  Color _mapProcessToColor(String processName) {
    final lowerName = processName.toLowerCase();

    // Browser colors
    if (lowerName.contains('chrome')) return Colors.blue;
    if (lowerName.contains('firefox')) return Colors.orange;
    if (lowerName.contains('edge')) return Colors.cyan;

    // Development colors
    if (lowerName.contains('vscode') || lowerName.contains('code')) {
      return Colors.blue;
    }
    if (lowerName.contains('visual studio')) return Colors.purple;

    // Office colors
    if (lowerName.contains('word')) return Colors.blue;
    if (lowerName.contains('excel')) return Colors.green;
    if (lowerName.contains('powerpoint')) return Colors.red;

    // Communication colors
    if (lowerName.contains('slack')) return Colors.purple;
    if (lowerName.contains('discord')) return const Color(0xFF5865F2);
    if (lowerName.contains('teams')) return Colors.purple;

    // Media colors
    if (lowerName.contains('spotify')) return Colors.green;
    if (lowerName.contains('youtube')) return Colors.red;

    // Default color
    return Colors.grey;
  }

  /// Clear caches
  void clearCaches() {
    _iconCache.clear();
    _colorCache.clear();
  }
}
