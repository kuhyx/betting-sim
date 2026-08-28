import 'dart:math' as math;

import 'package:league_engine/src/ratings/glicko2_types.dart';
import 'package:league_engine/src/ratings/glicko2_volatility.dart';

/// One result against one opponent, from the rated team's point of view.
class RatingResult {
  /// Creates a result. [score] is 1 for a win, 0.5 for a draw, 0 for a loss.
  const RatingResult({required this.opponent, required this.score});

  /// The opponent's rating as it stood at the start of the rating period.
  final Rating opponent;

  /// 1 win, 0.5 draw, 0 loss.
  final double score;
}

/// Applies Glicko-2 over one rating period.
class Glicko2Updater {
  /// Creates an updater with the given [config].
  const Glicko2Updater([this.config = const RatingConfig()]);

  /// Tunables shared with the volatility solver.
  final RatingConfig config;

  /// Returns [rating] updated by [results].
  ///
  /// An empty [results] is not an error: a team that did not play grows more
  /// uncertain rather than staying frozen, which is what makes RD mean
  /// "how current is this estimate" instead of merely "how many games".
  Rating update(Rating rating, List<RatingResult> results) {
    final self = rating.internal;

    if (results.isEmpty) {
      final phiPrime = math.sqrt(
        self.phi * self.phi + rating.volatility * rating.volatility,
      );
      return rating.copyWith(
        deviation: math.min(phiPrime * glicko2Scale, config.maxDeviation),
      );
    }

    // Step 3: estimated variance of the rating, from game outcomes alone.
    var vInv = 0.0;
    for (final r in results) {
      final opp = r.opponent.internal;
      final g = glickoG(opp.phi);
      final e = glickoE(self.mu, opp.mu, opp.phi);
      vInv += g * g * e * (1 - e);
    }
    final v = 1.0 / vInv;

    // Step 4: the estimated improvement implied by the results.
    var deltaSum = 0.0;
    for (final r in results) {
      final opp = r.opponent.internal;
      final g = glickoG(opp.phi);
      final e = glickoE(self.mu, opp.mu, opp.phi);
      deltaSum += g * (r.score - e);
    }
    final delta = v * deltaSum;

    // Step 5: the new volatility.
    final sigmaPrime = VolatilitySolver(config).solve(
      phi: self.phi,
      sigma: rating.volatility,
      delta: delta,
      v: v,
    );

    // Step 6-7: pre-period RD, then the new RD and rating.
    final phiStar = math.sqrt(
      self.phi * self.phi + sigmaPrime * sigmaPrime,
    );
    final phiPrime = 1.0 / math.sqrt(1.0 / (phiStar * phiStar) + 1.0 / v);
    final muPrime = self.mu + phiPrime * phiPrime * deltaSum;

    return Rating(
      rating: muPrime * glicko2Scale + glicko2Center,
      deviation: math.min(phiPrime * glicko2Scale, config.maxDeviation),
      volatility: sigmaPrime,
    );
  }
}
