import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/shared/models/motion_event.dart';
import 'package:motionarcade/shared/scoring/scoring_system.dart';

void main() {
  group('ScoringSystem Tests', () {
    late ScoringSystem scoring;

    setUp(() {
      scoring = ScoringSystem();
    });

    test('initial state is zero', () {
      expect(scoring.score, equals(0));
      expect(scoring.combo, equals(0));
      expect(scoring.maxCombo, equals(0));
      expect(scoring.multiplier, equals(1.0));
    });

    test('registerHit perfect increases score by 100 and combo by 1', () {
      final added = scoring.registerHit(FeedbackResult.perfect);
      expect(added, equals(100));
      expect(scoring.score, equals(100));
      expect(scoring.combo, equals(1));
      expect(scoring.maxCombo, equals(1));
    });

    test('multiplier increases with combo', () {
      for (var i = 0; i < 4; i++) {
        scoring.registerHit(FeedbackResult.perfect);
      }
      expect(scoring.combo, equals(4));
      expect(scoring.multiplier, equals(1.0));
      expect(scoring.score, equals(400));

      final added = scoring.registerHit(FeedbackResult.perfect);
      expect(added, equals(150));
      expect(scoring.score, equals(550));
      expect(scoring.combo, equals(5));
      expect(scoring.multiplier, equals(1.5));
    });

    test('miss resets combo to zero and does not add score', () {
      scoring.registerHit(FeedbackResult.perfect);
      scoring.registerHit(FeedbackResult.perfect);
      expect(scoring.combo, equals(2));

      final added = scoring.registerHit(FeedbackResult.miss);
      expect(added, equals(0));
      expect(scoring.combo, equals(0));
      expect(scoring.score, equals(200));
    });

    test('reset clears all stats', () {
      scoring.registerHit(FeedbackResult.perfect);
      scoring.registerHit(FeedbackResult.perfect);
      scoring.reset();

      expect(scoring.score, equals(0));
      expect(scoring.combo, equals(0));
      expect(scoring.maxCombo, equals(0));
      expect(scoring.multiplier, equals(1.0));
    });
  });
}
