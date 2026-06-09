import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../shared/models/fused_motion_sample.dart';
import 'calibration_service.dart';

class FusedMotionService {
  FusedMotionService({
    Stream<dynamic>? nativeEvents,
    Stream<UserAccelerometerEvent>? fallbackUserAccelerometerEvents,
    Stream<GyroscopeEvent>? fallbackGyroscopeEvents,
    EventChannel eventChannel = const EventChannel('motionarcade/fused_motion'),
    CalibrationService? calibrationService,
  }) : _nativeEvents = nativeEvents,
       _fallbackUserAccelerometerEvents = fallbackUserAccelerometerEvents,
       _fallbackGyroscopeEvents = fallbackGyroscopeEvents,
       _eventChannel = eventChannel,
       _calibrationService = calibrationService ?? CalibrationService();

  final Stream<dynamic>? _nativeEvents;
  final Stream<UserAccelerometerEvent>? _fallbackUserAccelerometerEvents;
  final Stream<GyroscopeEvent>? _fallbackGyroscopeEvents;
  final EventChannel _eventChannel;
  final CalibrationService _calibrationService;
  final StreamController<FusedMotionSnapshot> _snapshotController =
      StreamController<FusedMotionSnapshot>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<UserAccelerometerEvent>? _fallbackAccelerationSubscription;
  StreamSubscription<GyroscopeEvent>? _fallbackGyroscopeSubscription;
  FusedMotionSnapshot _snapshot = const FusedMotionSnapshot();
  Vector3Sample _fallbackRotationRate = const Vector3Sample(x: 0, y: 0, z: 0);

  Stream<FusedMotionSnapshot> get snapshots => _snapshotController.stream;
  FusedMotionSnapshot get currentSnapshot => _snapshot;
  bool get isActive => _snapshot.isActive;

  void start() {
    if (isActive) {
      return;
    }

    _setSnapshot(_snapshot.copyWith(isActive: true, clearError: true));
    final stream = _nativeEvents ?? _eventChannel.receiveBroadcastStream();
    _subscription = stream.listen(
      (event) {
        if (event is! Map) {
          _setSnapshot(
            _snapshot.copyWith(
              errorMessage: 'Unexpected fused motion payload: $event',
            ),
          );
          return;
        }

        final sample = FusedMotionSample.fromMap(event);
        final controllerSample = _calibrationService.applyToFusedMotion(sample);
        _setSnapshot(
          _snapshot.copyWith(
            sample: sample,
            controllerSample: controllerSample,
            clearError: true,
          ),
        );
      },
      onError: (Object error) {
        if (error is MissingPluginException) {
          unawaited(_startFallback('Native fused motion bridge unavailable.'));
          return;
        }

        _setSnapshot(
          _snapshot.copyWith(
            isActive: false,
            errorMessage: 'Fused motion error: $error',
          ),
        );
      },
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    await _fallbackAccelerationSubscription?.cancel();
    await _fallbackGyroscopeSubscription?.cancel();
    _subscription = null;
    _fallbackAccelerationSubscription = null;
    _fallbackGyroscopeSubscription = null;
    _setSnapshot(_snapshot.copyWith(isActive: false));
  }

  Future<void> dispose() async {
    await stop();
    await _snapshotController.close();
  }

  void _setSnapshot(FusedMotionSnapshot snapshot) {
    _snapshot = snapshot;
    _snapshotController.add(snapshot);
  }

  Future<void> _startFallback(String reason) async {
    await _subscription?.cancel();
    _subscription = null;
    if (!isActive) {
      return;
    }

    _setSnapshot(
      _snapshot.copyWith(
        isActive: true,
        errorMessage: '$reason Using userAccelerometer fallback.',
      ),
    );

    _fallbackGyroscopeSubscription =
        (_fallbackGyroscopeEvents ?? gyroscopeEventStream()).listen(
          (event) {
            _fallbackRotationRate = Vector3Sample(
              x: event.x,
              y: event.y,
              z: event.z,
            );
          },
          onError: (Object error) {
            _setSnapshot(
              _snapshot.copyWith(
                errorMessage: 'Fallback gyroscope error: $error',
              ),
            );
          },
        );

    _fallbackAccelerationSubscription =
        (_fallbackUserAccelerometerEvents ?? userAccelerometerEventStream())
            .listen(
              (event) {
                final sample = FusedMotionSample(
                  attitude: QuaternionSample.identity,
                  gravity: const Vector3Sample(x: 0, y: 0, z: 0),
                  userAcceleration: Vector3Sample(
                    x: event.x,
                    y: event.y,
                    z: event.z,
                  ),
                  rotationRate: _fallbackRotationRate,
                  timestamp: event.timestamp,
                  source: 'sensors_plus_user_accelerometer_fallback',
                );
                final controllerSample = _calibrationService.applyToFusedMotion(
                  sample,
                );
                _setSnapshot(
                  _snapshot.copyWith(
                    sample: sample,
                    controllerSample: controllerSample,
                    isActive: true,
                    errorMessage: '$reason Using userAccelerometer fallback.',
                  ),
                );
              },
              onError: (Object error) {
                _setSnapshot(
                  _snapshot.copyWith(
                    isActive: false,
                    errorMessage: 'Fallback userAccelerometer error: $error',
                  ),
                );
              },
            );
  }
}
