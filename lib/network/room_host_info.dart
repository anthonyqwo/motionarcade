class RoomHostInfo {
  const RoomHostInfo({
    required this.ipAddress,
    required this.port,
    this.udpPort,
  });

  final String ipAddress;
  final int port;
  final int? udpPort;

  Uri get uri => Uri.parse(connectionUri);
  Uri? get udpUri =>
      udpPort == null ? null : Uri.parse('udp://$ipAddress:$udpPort');

  String get connectionUri => 'ws://$ipAddress:$port';
}
