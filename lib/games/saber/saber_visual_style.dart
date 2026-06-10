import 'package:flutter/material.dart';

import '../../shared/models/motion_event.dart';

Color saberColorForDirection(MotionDirection direction) {
  return switch (direction) {
    MotionDirection.up || MotionDirection.down => const Color(0xFF22D3EE),
    MotionDirection.left => const Color(0xFFF97316),
    MotionDirection.right => const Color(0xFFA3E635),
    MotionDirection.forward => const Color(0xFF22C55E),
    MotionDirection.backward => const Color(0xFFFF4EBD),
  };
}

Color saberScoreColorForResult(FeedbackResult result) {
  return switch (result) {
    FeedbackResult.perfect => const Color(0xFFFFF7AD),
    FeedbackResult.good => const Color(0xFF22D3EE),
    FeedbackResult.weak => const Color(0xFFF97316),
    FeedbackResult.miss => const Color(0xFFFF4E50),
  };
}

String saberScoreLabel({
  required FeedbackResult result,
  required int addedScore,
}) {
  return switch (result) {
    FeedbackResult.perfect => 'PERFECT +$addedScore',
    FeedbackResult.good => 'GOOD +$addedScore',
    FeedbackResult.weak => 'WEAK +$addedScore',
    FeedbackResult.miss => 'MISS',
  };
}
