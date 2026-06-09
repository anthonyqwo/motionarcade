import 'dart:math' as math;

class DepthTransform {
  const DepthTransform({
    this.minScale = 0.42,
    this.maxScale = 1.24,
    this.minOpacity = 0.22,
    this.maxOpacity = 1,
  });

  final double minScale;
  final double maxScale;
  final double minOpacity;
  final double maxOpacity;

  double scaleForDepth(double depth) {
    final t = _normalized(depth);
    return minScale + (maxScale - minScale) * _easeOut(t);
  }

  double opacityForDepth(double depth) {
    final t = _normalized(depth);
    return minOpacity + (maxOpacity - minOpacity) * t;
  }

  double yOffsetForDepth(double depth, double travel) {
    final t = _normalized(depth);
    return travel * (1 - _easeOut(t));
  }

  double _normalized(double depth) {
    return depth.clamp(0.0, 1.0);
  }

  double _easeOut(double t) {
    return 1 - math.pow(1 - t, 2).toDouble();
  }
}
