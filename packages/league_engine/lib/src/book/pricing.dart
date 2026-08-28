import 'package:league_engine/src/book/margin.dart';
import 'package:league_engine/src/book/odds.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// Which side of a match a bet is on.
enum Selection {
  /// The home side wins.
  home,

  /// The match is drawn.
  draw,

  /// The away side wins.
  away,
}

/// A priced market on one match.
class Market {
  /// Creates a market.
  const Market({
    required this.prices,
    required this.limit,
    required this.margin,
  });

  /// Prices in [Selection] order.
  final List<Odds> prices;

  /// The largest stake the book will accept right now.
  final double limit;

  /// The overround actually embedded in [prices].
  final double margin;

  /// The price for [selection].
  Odds priceOf(Selection selection) => prices[selection.index];

  /// The book's implied probabilities, margin included. Sums above 1.
  List<double> get impliedProbabilities => <double>[
    for (final o in prices) o.impliedProbability,
  ];

  /// The book's opinion with the margin stripped out. Sums to 1.
  ///
  /// This is what a player must beat: not the quoted price, but the book's
  /// actual estimate hiding behind it.
  List<double> get fairProbabilities => removeVig(impliedProbabilities);

  @override
  String toString() {
    final rendered = prices.map((o) => o.toString()).join('/');
    return 'Market($rendered, ${(margin * 100).toStringAsFixed(1)}%)';
  }
}

/// Turns probabilities into a priced market.
class Bookmaker {
  /// Creates a bookmaker.
  const Bookmaker({
    this.marginMethod = const ProportionalMargin(0.05),
    this.openingLimit = 50,
  });

  /// How the margin is applied.
  final MarginMethod marginMethod;

  /// The stake accepted on a freshly opened market, before it sharpens.
  final double openingLimit;

  /// Prices [probs], which are the book's own estimate of the truth.
  ///
  /// Note the book prices its ESTIMATE, not the truth: [probs] normally comes
  /// from the book's model, which is deliberately noisier than the engine's
  /// own probabilities. That gap is the player's entire opportunity.
  Market price(OutcomeProbs probs, {double? limit}) {
    final priced = marginMethod.apply(probs.asList);
    final total = priced.reduce((a, b) => a + b);
    return Market(
      prices: <Odds>[for (final p in priced) Odds.fromProbability(p)],
      limit: limit ?? openingLimit,
      margin: total - 1,
    );
  }
}
