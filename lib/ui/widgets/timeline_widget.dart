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

class TimelineWidget extends StatelessWidget {
  final List<ActiveWindowEvent> events;

  const TimelineWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No timeline data',
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
        itemCount: events.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final event = events[index];
          final duration = event.durationMs / 1000;
          final durationStr = _formatDuration(duration.toInt());
          final dateTime =
              DateTime.fromMillisecondsSinceEpoch(event.tsUtc * 1000);
          final timeStr =
              '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
                            processName: event.processName,
                            executablePath: event.executablePath,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.processName,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (event.windowTitle != null &&
                                    event.windowTitle!.isNotEmpty)
                                  Text(
                                    event.windowTitle!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          durationStr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
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
