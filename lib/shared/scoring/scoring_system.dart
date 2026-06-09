import '../models/motion_event.dart';

class ScoringSystem {
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;

  int get score => _score;
  int get combo => _combo;
  int get maxCombo => _maxCombo;

  double get multiplier {
    if (_combo >= 20) return 3.0;
    if (_combo >= 15) return 2.5;
    if (_combo >= 10) return 2.0;
    if (_combo >= 5) return 1.5;
    return 1.0;
  }

  /// Registers a hit result, updates the score/combo/multiplier, and returns the added score.
  int registerHit(FeedbackResult result) {
    if (result == FeedbackResult.miss) {
      _combo = 0;
      return 0;
    }

    _combo++;
    if (_combo > _maxCombo) {
      _maxCombo = _combo;
    }

    final int baseScore = switch (result) {
      FeedbackResult.perfect => 100,
      FeedbackResult.good => 60,
      FeedbackResult.weak => 30,
      FeedbackResult.miss => 0,
    };

    final addedScore = (baseScore * multiplier).round();
    _score += addedScore;

    return addedScore;
  }

  void reset() {
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
  }
}
