import 'dart:math' as math;

/// The Glicko-2 scaling constant: 173.7178 rating points per internal unit.
const double glicko2Scale = 173.7178;

/// The rating the display scale is centred on.
const double glicko2Center = 1500;

/// A team's strength estimate.
///
/// [rating] is the point estimate. [deviation] (RD) is how unsure the system
/// is about it, and is load-bearing twice over: it drives how foggy scouting
/// looks to the player AND how wide the book's opening line is. "How much do
/// we know about this team" is therefore one number, not two systems.
///
/// [volatility] is how erratic the team's results have been -- a team that
/// swings between thrashings and defeats keeps a higher volatility, so its
/// rating stays responsive instead of being averaged into the middle.
class Rating {
  /// Creates a rating on the display scale.
  const Rating({
    this.rating = glicko2Center,
    this.deviation = 350.0,
    this.volatility = 0.06,
  });

  /// The point estimate, on the display scale (1500 = average).
  final double rating;

  /// The rating deviation (RD): the uncertainty around [rating].
  final double deviation;

  /// How erratic this team's results have been.
  final double volatility;

  /// This rating converted to Glicko-2's internal scale, where the centre is
  /// zero and one unit is [glicko2Scale] display points.
  ({double mu, double phi}) get internal => (
    mu: (rating - glicko2Center) / glicko2Scale,
    phi: deviation / glicko2Scale,
  );

  /// A 95% confidence interval on the display scale.
  ///
  /// This is what a scouting screen shows instead of a single number: a team
  /// with RD 350 is genuinely unknown, and the UI should say so.
  ({double low, double high}) get interval => (
    low: rating - 2 * deviation,
    high: rating + 2 * deviation,
  );

  /// Returns a copy with the given fields replaced.
  Rating copyWith({double? rating, double? deviation, double? volatility}) {
    return Rating(
      rating: rating ?? this.rating,
      deviation: deviation ?? this.deviation,
      volatility: volatility ?? this.volatility,
    );
  }

  @override
  String toString() {
    final r = rating.toStringAsFixed(1);
    final d = deviation.toStringAsFixed(1);
    return 'Rating($r ±$d)';
  }
}

/// Tunables for the rating system.
class RatingConfig {
  /// Creates a config. Defaults follow Glickman's recommendations.
  const RatingConfig({
    this.tau = 0.5,
    this.convergence = 0.000001,
    this.maxIterations = 100,
    this.maxDeviation = 350.0,
  });

  /// Constrains how much [Rating.volatility] may move in one rating period.
  ///
  /// Glickman suggests 0.3-1.2; smaller is steadier. Too large and a single
  /// freak result sends a team's rating flying.
  final double tau;

  /// The convergence tolerance for the volatility solver.
  final double convergence;

  /// A hard stop on solver iterations, so a pathological input cannot hang
  /// the simulation. Unreachable from real match data by design.
  final int maxIterations;

  /// The ceiling on RD, reached by a team that has not played in a long time.
  final double maxDeviation;
}

/// Glicko-2's `g` factor: how much an opponent's uncertainty dilutes the
/// information a result carries.
double glickoG(double phi) =>
    1.0 / math.sqrt(1.0 + 3.0 * phi * phi / (math.pi * math.pi));

/// The expected score against an opponent, on the internal scale.
double glickoE(double mu, double opponentMu, double opponentPhi) =>
    1.0 / (1.0 + math.exp(-glickoG(opponentPhi) * (mu - opponentMu)));
