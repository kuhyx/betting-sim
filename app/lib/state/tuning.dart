import 'package:flutter/foundation.dart';
import 'package:league_engine/league_engine.dart';

/// The balance knobs a debug build may change at runtime.
///
/// A frozen value object rather than loose fields on [GameState]: changing any
/// of these changes PRICING, so the season it produced is no longer comparable
/// and has to be regenerated. Keeping them together makes "did the tuning
/// change?" a single equality check instead of four correct comparisons, one
/// of which would eventually be forgotten.
///
/// The defaults are the shipped values, and they are duplicated here on
/// purpose: the engine's own defaults stay authoritative for the acceptance
/// gate, and this class only decides what the APP starts with.
@immutable
class Tuning {
  /// Creates a tuning set.
  const Tuning({
    this.bookLatentAwareness = 0.7,
    this.strengthScale = 0.006,
    this.fatigueAttackPenalty = 0.22,
    this.margin = 0.05,
  });

  /// How much of the clubs' hidden state the book manages to price.
  ///
  /// The balance point of the whole game. At 1.0 the book prices latent state
  /// perfectly and a studious player cannot win; at 0.0 the market is so soft
  /// that even a random bettor profits. Measured over 80 seasons per setting,
  /// the skilled bettor earned -4.54% at 1.00, +3.21% at 0.70 and +9.47% at
  /// 0.50, while the random bettor stayed near -4% throughout.
  final double bookLatentAwareness;

  /// How strongly a rating difference moves the scoring rates.
  final double strengthScale;

  /// How much full fatigue cuts scoring.
  ///
  /// Raising it makes the hidden state matter more, which widens the gap the
  /// book is blind to and so interacts with [bookLatentAwareness].
  final double fatigueAttackPenalty;

  /// The book's overround.
  ///
  /// The house edge: a random bettor's ROI converges to `-margin/(1+margin)`.
  final double margin;

  /// This tuning with one field replaced.
  Tuning copyWith({
    double? bookLatentAwareness,
    double? strengthScale,
    double? fatigueAttackPenalty,
    double? margin,
  }) {
    return Tuning(
      bookLatentAwareness: bookLatentAwareness ?? this.bookLatentAwareness,
      strengthScale: strengthScale ?? this.strengthScale,
      fatigueAttackPenalty: fatigueAttackPenalty ?? this.fatigueAttackPenalty,
      margin: margin ?? this.margin,
    );
  }

  /// The scoreline model this tuning implies.
  DixonColesModel get model =>
      DixonColesModel(ScoringConfig(strengthScale: strengthScale));

  /// The latent-layer config this tuning implies.
  LatentConfig get latentConfig =>
      LatentConfig(fatigueAttackPenalty: fatigueAttackPenalty);

  /// The bookmaker this tuning implies.
  Bookmaker get bookmaker =>
      Bookmaker(marginMethod: ProportionalMargin(margin));

  @override
  bool operator ==(Object other) =>
      other is Tuning &&
      other.bookLatentAwareness == bookLatentAwareness &&
      other.strengthScale == strengthScale &&
      other.fatigueAttackPenalty == fatigueAttackPenalty &&
      other.margin == margin;

  @override
  int get hashCode => Object.hash(
    bookLatentAwareness,
    strengthScale,
    fatigueAttackPenalty,
    margin,
  );
}
