import 'package:league_engine/src/bettors/estimate.dart';
import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';

/// A disciplined player who studies fixture congestion.
///
/// This is the acceptance gate's actual subject, and its edge is EARNED rather
/// than granted. It never reads the true probabilities. Instead it exploits a
/// modelled information asymmetry:
///
///   * The book's opening line is the truth plus noise, and it prices no
///     latent state at all.
///   * Fixture lists are public, so a diligent player can estimate how tired a
///     club is -- and fatigue is a large, real, unpriced effect (a fully spent
///     side carries an attack multiplier of 0.78).
///
/// So the player's model is the book's own published opinion, corrected for
/// the one thing the book ignores. If that correction is worth less than the
/// margin, the player loses; the gate is a genuine question either way.
class SkilledBettor implements Bettor {
  /// Creates a skilled bettor.
  const SkilledBettor({
    this.edgeThreshold = 0.03,
    this.kelly = 0.25,
    this.model = const DixonColesModel(),
  });

  /// The minimum edge worth backing, over and above the price.
  ///
  /// Discipline: refusing thin edges is most of what separates a winning
  /// player from a losing one, and it is why many matchdays see no bet at all.
  final double edgeThreshold;

  /// Kelly fraction. Quarter-Kelly is standard practice: full Kelly maximises
  /// growth but routinely halves a bankroll.
  final double kelly;

  /// Used only to re-price the book's opinion under observed fatigue, never
  /// to read the truth.
  final DixonColesModel model;

  @override
  String get name => 'skilled';

  @override
  List<Bet> betsFor(BettingView view, double bankroll, RandomSource rng) {
    final estimate = studiedEstimate(view, model);
    final bets = <Bet>[];

    for (final selection in Selection.values) {
      final p = estimate[selection.index];
      final odds = view.market.priceOf(selection);
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
