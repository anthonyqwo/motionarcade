import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/network/room_connection_uri.dart';

void main() {
  group('RoomConnectionUri', () {
    test('keeps a valid WebSocket room address', () {
      final uri = RoomConnectionUri.normalize('ws://192.168.1.20:8080');

      expect(uri, isNotNull);
      expect(uri.toString(), 'ws://192.168.1.20:8080');
    });

    test('accepts host and port without a WebSocket scheme', () {
      final uri = RoomConnectionUri.normalize('192.168.1.20:8080');

      expect(uri, isNotNull);
      expect(uri.toString(), 'ws://192.168.1.20:8080');
    });

    test('adds the default room port when the port is omitted', () {
      final uri = RoomConnectionUri.normalize('192.168.1.20');

      expect(uri, isNotNull);
      expect(uri.toString(), 'ws://192.168.1.20:8080');
    });

    test('converts browser-style room URLs into WebSocket URLs', () {
      final uri = RoomConnectionUri.normalize('http://192.168.1.20:8080');

      expect(uri, isNotNull);
      expect(uri.toString(), 'ws://192.168.1.20:8080');
    });

    test('rejects empty and incomplete addresses', () {
      expect(RoomConnectionUri.normalize(''), isNull);
      expect(RoomConnectionUri.normalize('ws://'), isNull);
    });
  });
}
