import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';

/// Bets with perfect knowledge of the true probabilities.
///
/// NOT a subject of the acceptance gate -- it cheats by construction. It is
/// the HEADROOM CONTROL: if even an oracle cannot clear the margin over a
/// season, the game is unwinnable and no amount of tuning the skilled bettor
/// will fix it. It answers "is gate 1 reachable at all" before we ask "does
/// this strategy reach it".
class OracleBettor implements Bettor {
  /// Creates an oracle.
  const OracleBettor({
    this.model = const DixonColesModel(),
    this.edgeThreshold = 0.02,
    this.kelly = 0.25,
  });

  /// The engine's own model, read directly. This is the cheat.
  final DixonColesModel model;

  /// The minimum edge worth backing.
  final double edgeThreshold;

  /// Kelly fraction.
  final double kelly;

  @override
  String get name => 'oracle';

  @override
  List<Bet> betsFor(BettingView view, double bankroll, RandomSource rng) {
    final truth = model.outcomeProbabilities(view.context).asList;
    final bets = <Bet>[];

    for (final selection in Selection.values) {
      final p = truth[selection.index];
      final odds = view.market.priceOf(selection);
      // Edge is measured against the PRICE, so the margin must be overcome
      // before a bet is worth making -- exactly as it is for a real bettor.
      final edge = p * odds.decimal - 1;
      if (edge < edgeThreshold) {
        continue;
      }
      final fraction = kellyFraction(
        probability: p,
        odds: odds,
        fraction: kelly,
      );
      final stake = _cap(bankroll * fraction, view.market.limit);
      if (stake > 0) {
        bets.add(Bet(selection: selection, stake: stake, taken: odds));
      }
    }
    return bets;
  }

  static double _cap(double stake, double limit) =>
      stake > limit ? limit : stake;
}
