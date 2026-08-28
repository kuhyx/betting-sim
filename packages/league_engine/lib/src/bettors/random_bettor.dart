import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/source.dart';

/// Backs a uniformly random outcome at a flat stake.
///
/// Gate 3's control. Under a proportional margin its expected ROI is exactly
/// -v/(1+v), independent of the true probabilities and of which outcome it
/// picks, so it measures the house edge and nothing else. If this comes out
/// anywhere else, the bookmaker is miscalibrated.
class RandomBettor implements Bettor {
  /// Creates a random bettor staking [stake] per match.
  const RandomBettor({this.stake = 10});

  /// The flat stake.
  final double stake;

  @override
  String get name => 'random';

  @override
  List<Bet> betsFor(BettingView view, double bankroll, RandomSource rng) {
    final selection = Selection.values[rng.randint(0, 2)];
    final size = stake > view.market.limit ? view.market.limit : stake;
    return <Bet>[
      Bet(
        selection: selection,
        stake: size,
        taken: view.market.priceOf(selection),
      ),
    ];
  }
}
