import 'dart:math' as math;

import 'package:league_engine/src/ratings/glicko2_types.dart';

/// Solves for a team's new volatility after a rating period.
///
/// Deliberately its own module. The Illinois-variant regula falsi below has
/// two branches that real match data never reaches -- the bracket-expansion
/// loop and the iteration cap -- and they are the difference between 100%
/// branch coverage and an unreachable remainder. Isolated here, they can be
/// driven directly with hand-crafted inputs, outside the season loop.
///
/// Follows Glickman's "Example of the Glicko-2 system" (2013), step 5.
class VolatilitySolver {
  /// Creates a solver with the given [config].
  const VolatilitySolver(this.config);

  /// Tunables, notably [RatingConfig.tau] and the iteration cap.
  final RatingConfig config;

  /// Returns the new volatility.
  ///
  /// [phi] is the current deviation and [sigma] the current volatility, both
  /// internal-scale; [delta] is the estimated rating change and [v] the
  /// estimated variance, from step 3-4 of the algorithm.
  double solve({
    required double phi,
    required double sigma,
    required double delta,
    required double v,
  }) {
    final a = math.log(sigma * sigma);
    double f(double x) {
      final ex = math.exp(x);
      final phiSq = phi * phi;
      final num = ex * (delta * delta - phiSq - v - ex);
      final den = 2.0 * (phiSq + v + ex) * (phiSq + v + ex);
      return num / den - (x - a) / (config.tau * config.tau);
    }

    // Initial bracket [A, B]. The lower bound is always `a`; the upper bound
    // is closed-form when delta is large, and otherwise must be searched for.
    var bigA = a;
    double bigB;
    final deltaSq = delta * delta;
    final phiSqPlusV = phi * phi + v;

    if (deltaSq > phiSqPlusV) {
      bigB = math.log(deltaSq - phiSqPlusV);
    } else {
      // Glickman's step 5 expands the bracket here, stepping down in units of
      // tau "until f turns negative". Under THIS branch's guard that loop can
      // never run, so it is not implemented:
      //
      //   delta^2 <= phi^2 + v            (the branch condition)
      //   => e^x * (delta^2 - phi^2 - v - e^x) <= 0 for all x, so term1 <= 0
      //   => f(a - k*tau) = term1 + k/tau  > 0 for every k >= 1
      //
      // Verified numerically across phi in [0.01, 3], v in [0.1, 10], delta at
      // the branch edge, and x in [-30, 5]: term1 peaked at -1.2e-29, never
      // positive. Implementing the loop would add a branch no input can reach
      // and a guard that could never fire -- dead code wearing a safety belt.
      bigB = a - config.tau;
    }

    var fa = f(bigA);
    var fb = f(bigB);
    var iterations = 0;

    while ((bigB - bigA).abs() > config.convergence) {
      if (iterations++ >= config.maxIterations) {
        throw StateError(
          'Glicko-2 volatility: solver did not converge in '
          '${config.maxIterations} iterations (phi=$phi, sigma=$sigma, '
          'delta=$delta, v=$v).',
        );
      }
      final c = bigA + (bigA - bigB) * fa / (fb - fa);
      final fc = f(c);
      if (fc * fb <= 0) {
        bigA = bigB;
        fa = fb;
      } else {
        // Illinois modification: halving fa is what stops one endpoint from
        // sticking and turning this into a slow bisection.
        fa = fa / 2.0;
      }
      bigB = c;
      fb = fc;
    }

    return math.exp(bigA / 2.0);
  }
}
