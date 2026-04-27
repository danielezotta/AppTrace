import 'package:flutter/material.dart';
import '../../models/activity_event.dart';
import '../../services/icon_service.dart';
import '../../services/windows_icon_service.dart';

class _AppIcon extends StatefulWidget {
  final String processName;
  final String? executablePath;
  final double size;

  const _AppIcon({
    required this.processName,
    required this.executablePath,
    this.size = 32,
  });

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  Future<ImageProvider?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.executablePath != widget.executablePath) {
      _load();
    }
  }

  void _load() {
    final path = widget.executablePath;
    _future = (path == null || path.isEmpty)
        ? Future.value(null)
        : WindowsIconService().getImageForExecutable(path);
  }

  @override
  Widget build(BuildContext context) {
    final iconService = IconService();
    final fallbackIcon = iconService.getIconForProcess(widget.processName);
    final fallbackColor = iconService.getColorForProcess(widget.processName);

    return FutureBuilder<ImageProvider?>(
      future: _future,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        if (provider != null) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  Icon(fallbackIcon, color: fallbackColor, size: widget.size),
            ),
          );
        }
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Icon(fallbackIcon, color: fallbackColor, size: widget.size),
        );
      },
    );
  }
}

class TopAppsWidget extends StatelessWidget {
  final List<DailyAggregate> apps;

  const TopAppsWidget({super.key, required this.apps});

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No activity recorded',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: apps.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final app = apps[index];
          final totalSeconds = app.totalMs ~/ 1000;
          final durationStr = _formatDuration(totalSeconds);
          final hours = app.totalMs / (1000 * 60 * 60);
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _AppIcon(
                            processName: app.processName,
                            executablePath: app.executablePath,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              app.processName,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      durationStr,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hours / (apps.first.totalMs / (1000 * 60 * 60)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      icon: Icons.keyboard_alt_outlined,
                      label: '${app.keys}',
                      tooltip: 'Total keystrokes detected while this app was active.',
                    ),
                    _MetricChip(
                      icon: Icons.mouse_outlined,
                      label: '${app.mouseClicks}',
                      tooltip: 'Total mouse clicks detected while this app was active.',
                    ),
                    _MetricChip(
                      icon: Icons.swap_vert,
                      label: '${app.mouseScrolls}',
                      tooltip: 'Total mouse wheel scroll steps detected while this app was active.',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else {
      return '${minutes}m ${secs}s';
    }
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
