import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/rng/source.dart';

/// Follows one named tipster, and only that one.
///
/// A CONTROL, not a subject, in the same spirit as `OracleBettor`: it is told
/// which tipster is sharp, and a player never is. It answers "is there
/// anything in the feed worth finding" before anyone asks whether a given
/// strategy finds it. If following the best voice in the game cannot beat the
/// margin, then keeping records is busywork and the feed is decoration.
class InsiderBettor implements Bettor {
  /// Creates a follower of tipster [tipsterId].
  const InsiderBettor({
    required this.tipsterId,
    this.edgeThreshold = 0.03,
    this.kelly = 0.25,
  });

  /// Whose calls to take.
  final int tipsterId;

  /// How far their opinion must beat the de-vigged price before betting.
  ///
  /// The same discipline the skilled bettor uses: refusing a thin edge is
  /// most of what separates a winning strategy from a losing one.
  final double edgeThreshold;

  /// Kelly fraction. Quarter, because full Kelly halves a bankroll routinely.
  final double kelly;

  @override
  String get name => 'insider';

  @override
  List<Bet> betsFor(BettingView view, double bankroll, RandomSource rng) {
    for (final tip in view.tips) {
      if (tip.tipsterId != tipsterId) {
        continue;
      }
      if (tip.edgeAgainst(view.market) < edgeThreshold) {
        return const <Bet>[];
      }
      final odds = view.market.priceOf(tip.selection);
      final fraction = kellyFraction(
        probability: tip.believedProbability,
        odds: odds,
        fraction: kelly,
      );
      final stake = bankroll * fraction;
      if (stake <= 0) {
        return const <Bet>[];
      }
      final capped = stake > view.market.limit ? view.market.limit : stake;
      return <Bet>[
        Bet(selection: tip.selection, stake: capped, taken: odds),
      ];
    }
    return const <Bet>[];
  }
}
