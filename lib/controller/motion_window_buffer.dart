import '../../shared/models/fused_motion_sample.dart';

class MotionWindowBuffer {
  MotionWindowBuffer({this.capacity = 120})
      : _buffer = List<FusedMotionSample?>.filled(capacity, null);

  final int capacity;
  final List<FusedMotionSample?> _buffer;
  int _head = 0;
  int _count = 0;

  void add(FusedMotionSample sample) {
    _buffer[_head] = sample;
    _head = (_head + 1) % capacity;
    if (_count < capacity) {
      _count++;
    }
  }

  void clear() {
    _buffer.fillRange(0, capacity, null);
    _head = 0;
    _count = 0;
  }

  int get length => _count;

  bool get isEmpty => _count == 0;

  /// Retrieves all samples currently in the buffer, ordered from oldest to newest.
  List<FusedMotionSample> get allSamples {
    final list = <FusedMotionSample>[];
    if (_count == 0) return list;

    final start = (_head - _count + capacity) % capacity;
    for (int i = 0; i < _count; i++) {
      final idx = (start + i) % capacity;
      final sample = _buffer[idx];
      if (sample != null) {
        list.add(sample);
      }
    }
    return list;
  }

  /// Retrieves a snapshot of samples covering the last [durationMs] milliseconds.
  /// It filters samples starting from the latest sample's timestamp back to [durationMs] ago.
  List<FusedMotionSample> getWindowSnapshot(int durationMs) {
    final list = <FusedMotionSample>[];
    if (_count == 0) return list;

    final sorted = allSamples;
    if (sorted.isEmpty) return list;

    final latestTime = sorted.last.timestamp;
    final thresholdTime = latestTime.subtract(Duration(milliseconds: durationMs));

    for (final sample in sorted) {
      if (sample.timestamp.isAfter(thresholdTime) ||
          sample.timestamp.isAtSameMomentAs(thresholdTime)) {
        list.add(sample);
      }
    }
    return list;
  }
}
