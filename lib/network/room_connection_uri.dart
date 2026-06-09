class RoomConnectionUri {
  const RoomConnectionUri._();

  static const int defaultPort = 8080;

  static Uri? normalize(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return null;
    }

    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    final withScheme = _withWebSocketScheme(normalized);
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        (uri.scheme != 'ws' && uri.scheme != 'wss') ||
        uri.host.isEmpty) {
      return null;
    }

    if (uri.hasPort) {
      return uri;
    }

    return uri.replace(port: defaultPort);
  }

  static String _withWebSocketScheme(String value) {
    final lower = value.toLowerCase();
    if (lower.startsWith('ws://') || lower.startsWith('wss://')) {
      return value;
    }
    if (lower.startsWith('http://')) {
      return 'ws://${value.substring('http://'.length)}';
    }
    if (lower.startsWith('https://')) {
      return 'wss://${value.substring('https://'.length)}';
    }
    return 'ws://$value';
  }
}
