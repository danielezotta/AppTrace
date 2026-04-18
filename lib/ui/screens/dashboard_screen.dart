import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/activity_service.dart';
import '../../models/activity_event.dart';
import '../widgets/top_apps_widget.dart';
import '../widgets/timeline_widget.dart';
import '../widgets/controls_widget.dart';
import '../widgets/custom_title_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ActivityService _activityService;
  DateTime _selectedDate = DateTime.now();
  List<DailyAggregate> _topApps = [];
  List<ActiveWindowEvent> _timeline = [];
  bool _isLoading = false;
  bool _isRecording = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _activityService = ActivityService();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Start monitoring
      await _activityService.startMonitoring();
      setState(() {
        _isRecording = true;
      });

      // Load initial data
      await _loadData();

      // Set up auto-refresh for today's data every 5 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_isToday(_selectedDate)) {
          // Aggregate today's data before loading (fire and forget)
          _activityService.aggregateDay(_selectedDate).then((_) {
            if (mounted) {
              _loadData();
            }
          });
        }
      });
    } catch (e) {
      print('Error initializing app: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final topApps = await _activityService.getTopApps(_selectedDate);
      final timeline = await _activityService.getTimeline(_selectedDate);

      setState(() {
        _topApps = topApps;
        _timeline = timeline;
      });
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changeDate(DateTime newDate) async {
    setState(() {
      _selectedDate = newDate;
    });
    await _loadData();
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        await _activityService.pauseRecording();
      } else {
        await _activityService.resumeRecording();
      }
      setState(() {
        _isRecording = !_isRecording;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _activityService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CustomTitleBar(
            title: 'AppTrace',
            trailing: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRecording ? 'Recording' : 'Paused',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date selector
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () =>
                                    _changeDate(_selectedDate.subtract(Duration(days: 1))),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _formatDate(_selectedDate),
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () =>
                                    _changeDate(_selectedDate.add(Duration(days: 1))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Controls
                          ControlsWidget(
                            isRecording: _isRecording,
                            onToggleRecording: _toggleRecording,
                            selectedDate: _selectedDate,
                          ),
                          const SizedBox(height: 24),

                          // Top apps section
                          Text(
                            'Top Apps',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TopAppsWidget(apps: _topApps),
                          const SizedBox(height: 24),

                          // Timeline section
                          Text(
                            'Timeline',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TimelineWidget(events: _timeline),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }
}
