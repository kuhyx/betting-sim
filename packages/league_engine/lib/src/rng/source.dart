import 'dart:math' as math;

import 'package:league_engine/src/rng/mix32.dart';

/// The only source of randomness in the engine.
///
/// Every stochastic function takes one of these explicitly. Nothing reads a
/// global RNG, which is what makes a single match replayable from its
/// sub-seed without recomputing the season around it.
abstract interface class RandomSource {
  /// A uniform double in [0, 1).
  double uniform01();

  /// A uniform integer in [low, high].
  int randint(int low, int high);

  /// A normal deviate with mean [mu] and standard deviation [sigma].
  double normal(double mu, double sigma);

  /// A Poisson deviate with rate [lambda].
  int poisson(double lambda);
}

/// The production [RandomSource], driven by the in-repo 32-bit mixer.
class Mix32Source implements RandomSource {
  /// Creates a source positioned at [seed].
  Mix32Source(this._state);

  int _state;

  /// The generator's current position, for tests that assert exact sequences.
  int get state => _state;

  int _nextRaw() {
    final step = mix32Next(_state);
    _state = step.state;
    return step.value;
  }

  @override
  double uniform01() {
    // Divide by 2^32 so the result lands in [0, 1). Computed as a double
    // division rather than a shift, because a 64-bit shift would not survive
    // compilation to JavaScript -- the same constraint that shaped mix32.
    return _nextRaw() / 4294967296.0;
  }

  @override
  int randint(int low, int high) {
    if (high < low) {
      throw ArgumentError('randint: high ($high) < low ($low)');
    }
    return low + (uniform01() * (high - low + 1)).floor();
  }

  @override
  double normal(double mu, double sigma) {
    // Box-Muller. `1 - uniform01()` moves the domain to (0, 1] so log() never
    // sees zero; uniform01() itself can return exactly 0.
    final u1 = 1.0 - uniform01();
    final u2 = uniform01();
    final r = math.sqrt(-2.0 * math.log(u1));
    return mu + sigma * r * math.cos(2 * math.pi * u2);
  }

  @override
  int poisson(double lambda) {
    if (lambda < 0) {
      throw ArgumentError('poisson: lambda ($lambda) must be >= 0');
    }
    // Knuth's product method. Fine for the small lambdas a low-scoring sport
    // produces (~0-5); it degrades for large lambda, which this sport never
    // reaches. Revisit only if a possession engine lands here.
    final limit = math.exp(-lambda);
    var k = 0;
    var p = 1.0;
    while (true) {
      p *= uniform01();
      if (p <= limit) {
        return k;
      }
      k++;
    }
  }
}
