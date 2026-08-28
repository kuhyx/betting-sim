/// How a price is written.
enum OddsFormat {
  /// 1.91 -- stake returned plus profit.
  decimal,

  /// 10/11 -- profit relative to stake.
  fractional,

  /// -110 -- stake needed to win 100, or profit on 100.
  american,
}

/// A price, held as a decimal and rendered on demand.
///
/// All three notations are offered because the game teaches betting maths, and
/// seeing the same price three ways is half the lesson.
class Odds {
  /// Creates a price from decimal odds.
  const Odds(this.decimal) : assert(decimal > 1, 'decimal odds must exceed 1');

  /// Creates a price from an implied probability.
  factory Odds.fromProbability(double p) {
    if (p <= 0 || p >= 1) {
      throw ArgumentError('probability must be in (0, 1), got $p');
    }
    return Odds(1 / p);
  }

  /// Decimal odds: total return per unit staked.
  final double decimal;

  /// Profit per unit staked.
  double get profit => decimal - 1;

  /// The probability this price implies, INCLUDING the book's margin.
  ///
  /// Summed across a market this exceeds 1; the excess is the overround.
  double get impliedProbability => 1 / decimal;

  /// American odds: negative for favourites, positive for underdogs.
  double get american =>
      decimal >= 2 ? (decimal - 1) * 100 : -100 / (decimal - 1);

  /// Fractional odds as a reduced numerator/denominator pair.
  ({int numerator, int denominator}) get fractional {
    // Approximate the profit as a fraction over a denominator that keeps the
    // familiar shapes (11/10, 5/2) rather than exact-but-ugly ratios.
    const denominators = <int>[1, 2, 3, 4, 5, 6, 8, 10, 16, 20, 40, 100];
    var best = (numerator: 1, denominator: 1);
    var bestError = double.infinity;
    for (final d in denominators) {
      final n = (profit * d).round();
      if (n < 1) {
        continue;
      }
      final error = (n / d - profit).abs();
      if (error < bestError) {
        bestError = error;
        best = (numerator: n, denominator: d);
      }
    }
    return best;
  }

  /// Renders this price in [format].
  String format(OddsFormat format) {
    switch (format) {
      case OddsFormat.decimal:
        return decimal.toStringAsFixed(2);
      case OddsFormat.fractional:
        final f = fractional;
        return '${f.numerator}/${f.denominator}';
      case OddsFormat.american:
        final a = american.round();
        return a > 0 ? '+$a' : '$a';
    }
  }

  @override
  String toString() => format(OddsFormat.decimal);
}
