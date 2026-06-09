import '../shared/models/motion_event.dart';

typedef MotionEventHandler<T extends MotionEvent> = void Function(T event);

class MotionEventDispatcher {
  MotionEventDispatcher({
    this.onJoin,
    this.onDisconnect,
    this.onButton,
    this.onCalibrate,
    this.onSwing,
    this.onSlash,
    this.onShoot,
    this.onShootHold,
    this.onMotionTrail,
    this.onFeedback,
    this.onTransportConfig,
    this.onUnknown,
  });

  final MotionEventHandler<JoinEvent>? onJoin;
  final MotionEventHandler<DisconnectEvent>? onDisconnect;
  final MotionEventHandler<ButtonEvent>? onButton;
  final MotionEventHandler<CalibrateEvent>? onCalibrate;
  final MotionEventHandler<SwingEvent>? onSwing;
  final MotionEventHandler<SlashEvent>? onSlash;
  final MotionEventHandler<ShootEvent>? onShoot;
  final MotionEventHandler<ShootHoldEvent>? onShootHold;
  final MotionEventHandler<MotionTrailEvent>? onMotionTrail;
  final MotionEventHandler<FeedbackEvent>? onFeedback;
  final MotionEventHandler<TransportConfigEvent>? onTransportConfig;
  final MotionEventHandler<UnknownMotionEvent>? onUnknown;

  void dispatch(MotionEvent event) {
    switch (event) {
      case JoinEvent():
        onJoin?.call(event);
      case DisconnectEvent():
        onDisconnect?.call(event);
      case ButtonEvent():
        onButton?.call(event);
      case CalibrateEvent():
        onCalibrate?.call(event);
      case SwingEvent():
        onSwing?.call(event);
      case SlashEvent():
        onSlash?.call(event);
      case ShootEvent():
        onShoot?.call(event);
      case ShootHoldEvent():
        onShootHold?.call(event);
      case MotionTrailEvent():
        onMotionTrail?.call(event);
      case FeedbackEvent():
        onFeedback?.call(event);
      case TransportConfigEvent():
        onTransportConfig?.call(event);
      case UnknownMotionEvent():
        onUnknown?.call(event);
    }
  }
}
