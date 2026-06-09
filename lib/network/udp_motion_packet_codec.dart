import 'dart:convert';

import '../shared/models/motion_event.dart';
import '../shared/models/motion_trail_sample.dart';

class UdpMotionTrailPacket {
  const UdpMotionTrailPacket({
    required this.roomToken,
    required this.sequence,
    required this.sentAt,
    required this.event,
  });

  final String roomToken;
  final int sequence;
  final DateTime sentAt;
  final MotionTrailEvent event;
}

class UdpMotionPacketCodec {
  const UdpMotionPacketCodec();

  String encodeTrail({
    required MotionTrailEvent event,
    required String roomToken,
    required int sequence,
  }) {
    return jsonEncode({
      'v': 1,
      'kind': 'trail',
      'room': roomToken,
      'playerId': event.playerId,
      'seq': sequence,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
      'timestamp': event.timestamp.millisecondsSinceEpoch,
      'referenceTimestamp': event.referenceTimestamp.millisecondsSinceEpoch,
      'samples': event.samples
          .map(
            (sample) => {
              't': sample.tMs,
              'x': sample.tipX,
              'y': sample.tipY,
              's': sample.strength,
            },
          )
          .toList(),
    });
  }

  UdpMotionTrailPacket decodeTrail(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('UDP motion packet must be a JSON object.');
    }
    if (decoded['kind'] != 'trail') {
      throw const FormatException('UDP motion packet kind must be trail.');
    }

    final playerId = _readString(decoded, 'playerId');
    final samples = (decoded['samples'] as List? ?? [])
        .map((sample) => _readSample(sample))
        .toList();

    return UdpMotionTrailPacket(
      roomToken: _readString(decoded, 'room'),
      sequence: _readInt(decoded, 'seq'),
      sentAt: _readTimestamp(decoded['sentAt']),
      event: MotionTrailEvent(
        playerId: playerId,
        timestamp: _readTimestamp(decoded['timestamp']),
        referenceTimestamp: _readTimestamp(decoded['referenceTimestamp']),
        samples: samples,
      ),
    );
  }

  MotionTrailSample _readSample(Object? value) {
    final map = value is Map<String, Object?>
        ? value
        : Map<String, Object?>.from(value as Map);
    return MotionTrailSample(
      tMs: _readInt(map, 't'),
      tipX: _readDouble(map, 'x'),
      tipY: _readDouble(map, 'y'),
      strength: _readDouble(map, 's'),
    );
  }

  String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('Missing string field: $key');
  }

  int _readInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    throw FormatException('Missing integer field: $key');
  }

  double _readDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('Missing numeric field: $key');
  }

  DateTime _readTimestamp(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    throw const FormatException('Missing timestamp field.');
  }
}
