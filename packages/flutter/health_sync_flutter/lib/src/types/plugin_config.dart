/// Plugin configuration options
class PluginConfig {
  /// Enable debug logging
  final bool debug;

  /// Custom configuration
  final Map<String, dynamic>? custom;

  const PluginConfig({
    this.debug = false,
    this.custom,
  });
}
