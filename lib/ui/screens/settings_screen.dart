import 'package:flutter/material.dart';
import '../../database/repository.dart';
import '../../services/startup_service.dart';
import '../../services/window_close_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ActivityRepository _repository = ActivityRepository();
  final StartupService _startupService = StartupService();
  List<Map<String, String>> _exclusions = [];
  final TextEditingController _processController = TextEditingController();
  final TextEditingController _windowTitleController = TextEditingController();
  String _selectedExclusionType = 'process';
  bool _startOnLogin = false;
  bool _isUpdatingStartOnLogin = false;
  bool _closeToTray = true;
  bool _isUpdatingCloseToTray = false;

  @override
  void initState() {
    super.initState();
    _loadExclusions();
    _loadStartupSetting();
    _loadCloseBehaviorSetting();
  }

  Future<void> _loadExclusions() async {
    final exclusions = await _repository.getExclusions();
    setState(() {
      _exclusions = exclusions;
    });
  }

  Future<void> _loadStartupSetting() async {
    final enabled = await _repository.isStartOnLoginEnabled();
    if (!mounted) {
      return;
    }

    setState(() {
      _startOnLogin = enabled;
    });
  }

  Future<void> _toggleStartOnLogin(bool enabled) async {
    if (_isUpdatingStartOnLogin) {
      return;
    }

    setState(() {
      _isUpdatingStartOnLogin = true;
    });

    try {
      await _startupService.setEnabled(enabled);
      await _repository.setStartOnLogin(enabled);

      if (mounted) {
        setState(() {
          _startOnLogin = enabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Start on login enabled'
                  : 'Start on login disabled',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStartOnLogin = false;
        });
      }
    }
  }

  Future<void> _loadCloseBehaviorSetting() async {
    final enabled = await _repository.isCloseToTrayEnabled();
    if (!mounted) {
      return;
    }

    setState(() {
      _closeToTray = enabled;
    });
  }

  Future<void> _toggleCloseToTray(bool enabled) async {
    if (_isUpdatingCloseToTray) {
      return;
    }

    setState(() {
      _isUpdatingCloseToTray = true;
    });

    try {
      await _repository.setCloseToTrayEnabled(enabled);
      await WindowCloseService().refreshPreference();

      if (mounted) {
        setState(() {
          _closeToTray = enabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Window close now hides to tray'
                  : 'Window close now exits the app',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCloseToTray = false;
        });
      }
    }
  }

  Future<void> _addExclusion() async {
    final pattern = _selectedExclusionType == 'process'
        ? _processController.text
        : _windowTitleController.text;

    if (pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a pattern')),
      );
      return;
    }

    try {
      await _repository.addExclusion(
        type: _selectedExclusionType,
        pattern: pattern,
      );

      _processController.clear();
      _windowTitleController.clear();

      await _loadExclusions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exclusion added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeExclusion(String type, String pattern) async {
    try {
      await _repository.removeExclusion(type: type, pattern: pattern);
      await _loadExclusions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exclusion removed')),
        );
      }
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
    _processController.dispose();
    _windowTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('Start on login'),
                subtitle: const Text(
                  'Launch AppTrace automatically when you sign in to Windows',
                ),
                value: _startOnLogin,
                onChanged: _isUpdatingStartOnLogin ? null : _toggleStartOnLogin,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                title: const Text('Close to tray'),
                subtitle: const Text(
                  'If enabled, closing the window keeps AppTrace running in the tray',
                ),
                value: _closeToTray,
                onChanged: _isUpdatingCloseToTray ? null : _toggleCloseToTray,
              ),
            ),
            const SizedBox(height: 24),

            // Privacy section
            Text(
              'Privacy & Exclusions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exclude apps and windows from tracking',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    // Exclusion type selector
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'process',
                          label: Text('Process Name'),
                        ),
                        ButtonSegment(
                          value: 'window_title',
                          label: Text('Window Title'),
                        ),
                      ],
                      selected: {_selectedExclusionType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedExclusionType = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Input field
                    if (_selectedExclusionType == 'process')
                      TextField(
                        controller: _processController,
                        decoration: InputDecoration(
                          labelText: 'Process name (e.g., chrome.exe)',
                          hintText: 'Use * for wildcards',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addExclusion,
                          ),
                        ),
                      )
                    else
                      TextField(
                        controller: _windowTitleController,
                        decoration: InputDecoration(
                          labelText: 'Window title pattern',
                          hintText: 'Use * for wildcards',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addExclusion,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Current exclusions
            Text(
              'Current Exclusions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_exclusions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No exclusions configured',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _exclusions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exclusion = _exclusions[index];
                    final type = exclusion['type'] ?? '';
                    final pattern = exclusion['pattern'] ?? '';

                    return ListTile(
                      title: Text(pattern),
                      subtitle: Text(type == 'process' ? 'Process' : 'Window Title'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            _removeExclusion(type, pattern),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
