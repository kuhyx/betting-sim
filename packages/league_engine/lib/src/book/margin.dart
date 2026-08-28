/// How a book turns true probabilities into priced ones.
///
/// Priced probabilities sum to more than 1; the excess is the overround, and
/// it is the house's entire income.
abstract interface class MarginMethod {
  /// The book's margin, e.g. 0.05 for 5%.
  double get margin;

  /// Returns [trueProbs] inflated by the margin. The result sums to 1 + v.
  List<double> apply(List<double> trueProbs);
}

/// Scales every outcome's probability by the same factor.
///
/// Implemented FIRST, and used for the acceptance gate, because it makes the
/// random bettor's expected return exactly solvable:
///
///   price_i = 1 / (p_i * (1 + v))
///   E[return per unit] = p_i * price_i = 1 / (1 + v)
///   E[ROI] = 1/(1+v) - 1 = -v/(1+v)
///
/// independent of the true probabilities AND of which outcome is chosen. That
/// turns "a random bettor loses at roughly the overround" from a Monte-Carlo
/// vibe check into an exact unit test.
///
/// Real books favour margins that lean harder on longshots; those go behind
/// this same interface later, and none of them has a clean closed form.
class ProportionalMargin implements MarginMethod {
  /// Creates a proportional margin of [margin], e.g. 0.05 for 5%.
  const ProportionalMargin(this.margin)
    : assert(margin >= 0, 'margin cannot be negative');

  @override
  final double margin;

  @override
  List<double> apply(List<double> trueProbs) => <double>[
    // Clamped just below 1: a true probability above 1/(1+v) would price
    // to a certainty, which has no valid decimal odds. Unreachable for
    // real fixtures -- this league's most one-sided match sits at 0.63,
    // against a 0.952 threshold at v=0.05 -- but a market on a near-certain
    // proposition must degrade rather than throw.
    for (final p in trueProbs) _cap(p * (1 + margin)),
  ];

  static double _cap(double p) => p >= 0.999 ? 0.999 : p;
}

/// Adds the margin evenly across outcomes rather than proportionally.
///
/// An even split is a LARGER relative mark-up on a small probability, so this
/// leans on longshots and spares favourites -- the real-world
/// favourite-longshot bias. At v=0.06 a 0.10 outcome is marked up x1.200
/// against a proportional x1.060, while a 0.70 outcome gets x1.029.
/// It puts the player's edge in a different part of the market.
class AdditiveMargin implements MarginMethod {
  /// Creates an additive margin.
  const AdditiveMargin(this.margin)
    : assert(margin >= 0, 'margin cannot be negative');

  @override
  final double margin;

  @override
  List<double> apply(List<double> trueProbs) {
    final share = margin / trueProbs.length;
    return <double>[
      for (final p in trueProbs) _cap(p + share),
    ];
  }

  static double _cap(double p) => p >= 0.999 ? 0.999 : p;
}

/// Strips the margin back out of a priced market.
///
/// This is the no-vig calculator the player is given: it is the only way to
/// compare the book's opinion with your own on equal terms, and the whole
/// notion of Closing Line Value rests on it.
List<double> removeVig(List<double> pricedProbs) {
  final total = pricedProbs.reduce((a, b) => a + b);
  return <double>[for (final p in pricedProbs) p / total];
}
