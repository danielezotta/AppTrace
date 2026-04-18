import 'package:flutter/material.dart';
import '../../database/repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ActivityRepository _repository = ActivityRepository();
  List<Map<String, String>> _exclusions = [];
  final TextEditingController _processController = TextEditingController();
  final TextEditingController _windowTitleController = TextEditingController();
  String _selectedExclusionType = 'process';

  @override
  void initState() {
    super.initState();
    _loadExclusions();
  }

  Future<void> _loadExclusions() async {
    final exclusions = await _repository.getExclusions();
    setState(() {
      _exclusions = exclusions;
    });
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
