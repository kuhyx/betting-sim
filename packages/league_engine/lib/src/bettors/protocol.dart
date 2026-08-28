import 'package:league_engine/src/book/odds.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// What a bettor is allowed to know before a match.
///
/// Deliberately NOT the true outcome probabilities. A strategy that could read
/// those would beat any book by construction, and measuring it would tell us
/// nothing about whether the game is learnable. This is the restricted view: a
/// market, and whatever public information the player has managed to gather.
class BettingView {
  /// Creates a view.
  const BettingView({
    required this.market,
    required this.context,
    this.observedHomeFatigue,
    this.observedAwayFatigue,
    this.observedHomeForm,
    this.observedAwayForm,
  });

  /// The prices on offer.
  final Market market;

  /// The match, including its published weather and team news.
  final MatchContext context;

  /// What the player believes about the home side's tiredness, if anything.
  ///
  /// This is the modelled information gap: fixture congestion is public, so a
  /// diligent player can estimate it, while the book's opening line does not
  /// price it. The edge is EARNED from that asymmetry rather than granted by
  /// giving the bettor quieter noise than the book.
  final double? observedHomeFatigue;

  /// What the player believes about the away side's tiredness, if anything.
  final double? observedAwayFatigue;

  /// What the player believes about the home side's recent form.
  ///
  /// The second half of the information gap. Results are public, so form is
  /// derivable by anyone who keeps records -- and the book's opening line
  /// prices no latent state at all. Fatigue alone shifts a probability by at
  /// most 1.5pp, short of the ~2.5pp needed to clear a 5% margin; form is what
  /// takes the combined signal over the line.
  final double? observedHomeForm;

  /// What the player believes about the away side's recent form.
  final double? observedAwayForm;
}

/// A bet placed at a price.
class Bet {
  /// Creates a bet.
  const Bet({
    required this.selection,
    required this.stake,
    required this.taken,
  });

  /// Which outcome was backed.
  final Selection selection;

  /// How much was staked.
  final double stake;

  /// The price taken. Kept for CLV, which compares it with the close.
  final Odds taken;

  /// Profit if this bet wins.
  double get potentialProfit => stake * taken.profit;

  @override
  String toString() =>
      'Bet(${selection.name} $stake @ ${taken.format(OddsFormat.decimal)})';
}

/// A betting strategy.
abstract interface class Bettor {
  /// How this strategy is labelled in the acceptance report.
  String get name;

  /// Returns the bets to place on this match, possibly none.
  ///
  /// Returning an empty list is a first-class outcome: refusing a bad price is
  /// most of what separates a disciplined player from a losing one.
  List<Bet> betsFor(BettingView view, double bankroll, RandomSource rng);
}

/// Settles a bet against a result.
double settle(Bet bet, MatchResult result) {
  final won = switch (bet.selection) {
    Selection.home => result.homeWon,
    Selection.draw => result.drawn,
    Selection.away => !result.homeWon && !result.drawn,
  };
  return won ? bet.potentialProfit : -bet.stake;
}

/// How much of a bankroll to stake on an edge, by the Kelly criterion.
///
/// f* = (bp - q)/b, where b is the profit multiple, p the believed win
/// probability and q = 1 - p. Full Kelly maximises long-run growth but halves
/// a bankroll routinely, which is why practitioners bet a fraction of it --
/// and why the game surfaces this number rather than hiding it.
double kellyFraction({
  required double probability,
  required Odds odds,
  double fraction = 0.25,
}) {
  final b = odds.profit;
  final edge = b * probability - (1 - probability);
  if (edge <= 0) {
    return 0;
  }
  return (edge / b) * fraction;
}
