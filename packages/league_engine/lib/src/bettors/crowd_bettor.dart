import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/source.dart';

/// Backs whatever the internet is loudest about.
///
/// The control for the feed, in the same way `RandomBettor` is the control for
/// the book: if reading tips were free money, THIS would find it, because it
/// does the thing everyone actually does -- follows the confident voices and
/// never checks whether they were right.
///
/// Weighted by [Tip.confidence], which is drawn independently of how much a
/// tipster knows. That is the trap the strategy walks into, and gate 4 exists
/// to assert it stays a trap.
class CrowdBettor implements Bettor {
  /// Creates a crowd-follower staking [stake] a match.
  const CrowdBettor({this.stake = 10});

  /// Flat stake. Flat, not Kelly, so the number this produces is a clean
  /// read on the tips rather than on a staking plan.
  final double stake;

  @override
  String get name => 'crowd';

  @override
  List<Bet> betsFor(BettingView view, double bankroll, RandomSource rng) {
    if (view.tips.isEmpty) {
      return const <Bet>[];
    }

    final shouting = <double>[0, 0, 0];
    for (final tip in view.tips) {
      shouting[tip.selection.index] += tip.confidence;
    }

    var pick = Selection.home;
    for (final s in Selection.values) {
      if (shouting[s.index] > shouting[pick.index]) {
        pick = s;
      }
    }

    final size = stake > bankroll ? bankroll : stake;
    if (size <= 0) {
      return const <Bet>[];
    }
    return <Bet>[
      Bet(selection: pick, stake: size, taken: view.market.priceOf(pick)),
    ];
  }
}
