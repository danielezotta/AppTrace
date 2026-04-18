import 'package:flutter/material.dart';
import '../../services/export_service.dart';
import '../screens/settings_screen.dart';

class ControlsWidget extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final DateTime selectedDate;

  const ControlsWidget({
    super.key,
    required this.isRecording,
    required this.onToggleRecording,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: onToggleRecording,
          icon: Icon(isRecording ? Icons.pause : Icons.play_arrow),
          label: Text(isRecording ? 'Pause' : 'Resume'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isRecording ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showExportDialog(context),
          icon: const Icon(Icons.download),
          label: const Text('Export'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showSettingsDialog(context),
          icon: const Icon(Icons.settings),
          label: const Text('Settings'),
        ),
      ],
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Choose what to export:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _exportDailyAggregates(context);
            },
            child: const Text('Daily Summary'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _exportTimeline(context);
            },
            child: const Text('Timeline'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDailyAggregates(BuildContext context) async {
    try {
      final exportService = ExportService();
      final startDate = selectedDate.subtract(const Duration(days: 30));
      final filePath = await exportService.exportAndSaveDailyAggregates(
        startDate: startDate,
        endDate: selectedDate,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: $filePath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportTimeline(BuildContext context) async {
    try {
      final exportService = ExportService();
      final startDate = selectedDate;
      final endDate = selectedDate.add(const Duration(days: 1));
      final filePath = await exportService.exportAndSaveTimeline(
        startDate: startDate,
        endDate: endDate,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: $filePath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}
