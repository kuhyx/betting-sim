import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/latent/modifiers.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

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
    final estimate = _estimate(view);
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

  /// The player's own probabilities: the book's de-vigged opinion, adjusted
  /// for whatever fatigue they have managed to observe.
  List<double> _estimate(BettingView view) {
    final bookOpinion = view.market.fairProbabilities;
    final homeFatigue = view.observedHomeFatigue;
    final awayFatigue = view.observedAwayFatigue;
    final homeForm = view.observedHomeForm;
    final awayForm = view.observedAwayForm;

    if (homeFatigue == null &&
        awayFatigue == null &&
        homeForm == null &&
        awayForm == null) {
      return bookOpinion;
    }

    // Re-price the match twice through the SAME model: once as the book sees
    // it (no fatigue) and once with the fatigue the player believes in. The
    // ratio between those is the correction to apply to the book's opinion,
    // so the player is never handed the truth -- only a delta the book missed.
    const modifiers = LatentModifiers();
    final neutral = model.outcomeProbabilities(
      MatchContext(
        home: view.context.home,
        away: view.context.away,
        homeModifiers: const MatchModifiers(),
        awayModifiers: const MatchModifiers(),
        seedPath: view.context.seedPath,
        weather: view.context.weather,
      ),
    );
    final adjusted = model.outcomeProbabilities(
      MatchContext(
        home: view.context.home,
        away: view.context.away,
        homeModifiers: modifiers.project(
          LatentState(fatigue: homeFatigue ?? 0),
        ),
        awayModifiers: modifiers.project(
          LatentState(fatigue: awayFatigue ?? 0),
        ),
        seedPath: view.context.seedPath,
        weather: view.context.weather,
      ),
    );

    final corrected = <double>[
      for (var i = 0; i < 3; i++)
        bookOpinion[i] * (adjusted.asList[i] / neutral.asList[i]),
    ];
    final total = corrected.reduce((a, b) => a + b);
    return <double>[for (final p in corrected) p / total];
  }

  static double _cap(double stake, double limit) =>
      stake > limit ? limit : stake;
}
