enum ConnectionStatus {
  idle,
  starting,
  connecting,
  connected,
  disconnected,
  unsupported,
  error,
}

extension ConnectionStatusLabel on ConnectionStatus {
  String get label => switch (this) {
    ConnectionStatus.idle => 'Idle',
    ConnectionStatus.starting => 'Starting',
    ConnectionStatus.connecting => 'Connecting',
    ConnectionStatus.connected => 'Connected',
    ConnectionStatus.disconnected => 'Disconnected',
    ConnectionStatus.unsupported => 'Unsupported',
    ConnectionStatus.error => 'Error',
  };
}
