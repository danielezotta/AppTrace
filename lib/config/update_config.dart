class UpdateConfig {
  // Set these before enabling update checks.
  static const String githubOwner = 'danielezotta';
  static const String githubRepo = 'AppTrace';

  static bool get isConfigured =>
      githubOwner.isNotEmpty && githubRepo.isNotEmpty;
}
