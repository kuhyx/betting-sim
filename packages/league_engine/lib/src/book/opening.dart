import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// Adds noise to the book's view of a match.
///
/// The book is good, not omniscient. Its opening estimate is the truth plus
/// error, and that error is the player's entire opportunity: beat the book's
/// estimate often enough and the margin stops mattering.
///
/// The noise shrinks as the book learns a club, which is why early-season
/// markets are the softest.
class OpeningLine {
  /// Creates an opening-line model.
  const OpeningLine({this.baseNoise = 0.05, this.uncertaintyWeight = 0.0004});

  /// Baseline error in the book's probability estimate.
  final double baseNoise;

  /// Extra error per point of combined rating deviation.
  ///
  /// Ties the book's confidence to the SAME rating-deviation number that
  /// drives scouting fog, so "nobody knows this club yet" widens the market
  /// and blurs the player's information at once.
  final double uncertaintyWeight;

  /// Returns the book's noisy estimate of [truth].
  ///
  /// [combinedDeviation] is the two clubs' rating deviations added together.
  OutcomeProbs estimate(
    OutcomeProbs truth,
    double combinedDeviation,
    RandomSource rng,
  ) {
    final sigma = baseNoise + uncertaintyWeight * combinedDeviation;
    final shifted = <double>[
      for (final p in truth.asList) _positive(p + rng.normal(0, sigma)),
    ];
    final total = shifted.reduce((a, b) => a + b);
    return OutcomeProbs(
      home: shifted[0] / total,
      draw: shifted[1] / total,
      away: shifted[2] / total,
    );
  }

  static double _positive(double p) => p < 0.01 ? 0.01 : p;
}
