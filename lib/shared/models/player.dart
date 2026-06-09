enum PlayerConnectionStatus { connected, disconnected }

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.deviceLabel,
    this.status = PlayerConnectionStatus.connected,
  });

  final String id;
  final String name;
  final String deviceLabel;
  final PlayerConnectionStatus status;
}
