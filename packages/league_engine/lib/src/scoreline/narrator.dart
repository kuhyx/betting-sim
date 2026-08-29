import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/attribution.dart';
import 'package:league_engine/src/scoreline/events.dart';
import 'package:league_engine/src/scoreline/lineup.dart';
import 'package:league_engine/src/scoreline/match_stats.dart';
import 'package:league_engine/src/scoreline/narration_config.dart';
import 'package:league_engine/src/scoreline/narration_slots.dart';
import 'package:league_engine/src/scoreline/protocol.dart';
import 'package:league_engine/src/scoreline/stat_draws.dart';
import 'package:league_engine/src/scoreline/timeline.dart';

/// Elaborates an already-played match into something worth watching.
///
/// ## Why this is not part of the scoreline model
///
/// `DixonColesModel.simulate` samples the score from the same corrected grid
/// that `outcomeProbabilities` integrates, and a test pins the two together
/// at 0.006. Generating stats inside `simulate` would consume draws from the
/// `possession: 1` stream, shifting every value after them -- every goal
/// minute, every later match, every frozen literal, and every existing save.
///
/// So the narrator takes a FINISHED [MatchResult] and opens its own sub-seeds
/// ([NarrationSlot]). The goal marginal cannot move, because nothing that
/// computes it changes: `dixon_coles.dart` and `poisson_params.dart` have an
/// empty diff, and that emptiness is the proof rather than a re-measured
/// gate number.
///
/// Which observable answers to which hidden factor -- and the one legitimate
/// coupling between them -- is the fingerprint table in
/// `DOCS-architecture.md`. So is the reason a side sometimes goes down to ten
/// men and still wins 3-0, which is a consequence to leave alone rather than
/// a bug to fix.
class MatchNarrator {
  /// Creates a narrator.
  const MatchNarrator([this.config = const NarrationConfig()]);

  /// Rates and thresholds.
  final NarrationConfig config;

  /// Narrates [result], which must already have been played from [ctx].
  MatchTimeline narrate(MatchContext ctx, MatchResult result) {
    final homeSheet = pickLineup(
      ctx.home,
      missingCount: ctx.homeModifiers.missingCount,
      config: config,
    );
    final awaySheet = pickLineup(
      ctx.away,
      missingCount: ctx.awayModifiers.missingCount,
      config: config,
    );

    // Public strength only. Deliberately NOT `ScoringRates`, which already
    // has all four latent factors blended into it and would smuggle every
    // one of them into every stat at once.
    final homeEdge = ctx.home.attackStrength - ctx.away.defenceStrength;
    final awayEdge = ctx.away.attackStrength - ctx.home.defenceStrength;

    final goals = result.events.whereType<GoalEvent>().toList();
    final home = _side(
      ctx: ctx,
      goals: result.homeScore,
      secondHalfGoals: _afterTheBreak(goals, byHome: true),
      edge: homeEdge,
      modifiers: ctx.homeModifiers,
      isHome: true,
    );
    final away = _side(
      ctx: ctx,
      goals: result.awayScore,
      secondHalfGoals: _afterTheBreak(goals, byHome: false),
      edge: awayEdge,
      modifiers: ctx.awayModifiers,
      isHome: false,
    );

    final homePossession = drawHomePossession(
      strengthEdge: homeEdge - awayEdge,
      moraleSpread:
          (ctx.homeModifiers.moraleSpread + ctx.awayModifiers.moraleSpread) / 2,
      config: config,
      rng: _rng(ctx, NarrationSlot.possessionSplit),
    );

    final events = <MatchEvent>[
      ...attributeGoals(
        goals: goals,
        homeSheet: homeSheet,
        awaySheet: awaySheet,
        rng: _rng(ctx, NarrationSlot.scorers),
      ),
      ..._cards(ctx, isHome: true, cards: home.cards, sheet: homeSheet),
      ..._cards(ctx, isHome: false, cards: away.cards, sheet: awaySheet),
      ..._injury(ctx, isHome: true, sheet: homeSheet),
      ..._injury(ctx, isHome: false, sheet: awaySheet),
    ];

    return MatchTimeline(
      events: inMatchOrder(events),
      home: home.build(homePossession),
      away: away.build(100 - homePossession),
      homeSheet: homeSheet,
      awaySheet: awaySheet,
    );
  }

  _SideStats _side({
    required MatchContext ctx,
    required int goals,
    required int secondHalfGoals,
    required double edge,
    required MatchModifiers modifiers,
    required bool isHome,
  }) {
    final shots = drawShots(
      strengthEdge: edge,
      lateMatchDecay: modifiers.lateMatchDecay,
      goals: goals,
      secondHalfGoals: secondHalfGoals,
      config: config,
      rng: _rng(
        ctx,
        isHome ? NarrationSlot.homeShots : NarrationSlot.awayShots,
      ),
    );
    final onTarget = drawShotsOnTarget(
      // total - goals, NOT firstHalf + secondHalf: since goals were filed
      // into their own half those two now sum to the total, and using them
      // would run a Bernoulli trial per goal as well.
      nonScoringShots: shots.total - goals,
      goals: goals,
      formShift: modifiers.formShift,
      config: config,
      rng: _rng(
        ctx,
        isHome ? NarrationSlot.homeOnTarget : NarrationSlot.awayOnTarget,
      ),
    );
    final corners = drawCorners(
      strengthEdge: edge,
      config: config,
      rng: _rng(
        ctx,
        isHome ? NarrationSlot.homeCorners : NarrationSlot.awayCorners,
      ),
    );
    final cards = drawDiscipline(
      refereeBias: ctx.refereeBias,
      config: config,
      rng: _rng(
        ctx,
        isHome ? NarrationSlot.homeDiscipline : NarrationSlot.awayDiscipline,
      ),
    );
    return _SideStats(goals, shots, onTarget, corners, cards);
  }

  List<MatchEvent> _cards(
    MatchContext ctx, {
    required bool isHome,
    required DisciplineDraw cards,
    required TeamSheet sheet,
  }) {
    return attributeCards(
      homeSide: isHome,
      yellows: cards.yellows,
      reds: cards.reds,
      sheet: sheet,
      rng: _rng(
        ctx,
        isHome ? NarrationSlot.homeCardees : NarrationSlot.awayCardees,
      ),
    );
  }

  List<InjuryEvent> _injury(
    MatchContext ctx, {
    required bool isHome,
    required TeamSheet sheet,
  }) {
    final rng = _rng(
      ctx,
      isHome ? NarrationSlot.homeInjury : NarrationSlot.awayInjury,
    );
    if (!drawInjury(config: config, rng: rng)) {
      return const <InjuryEvent>[];
    }
    final hurt = attributeInjury(
      homeSide: isHome,
      sheet: sheet,
      config: config,
      rng: rng,
    );
    return <InjuryEvent>[?hurt];
  }

  /// How many of one side's goals came after the interval.
  static int _afterTheBreak(List<GoalEvent> goals, {required bool byHome}) =>
      goals.where((g) => g.byHome == byHome && g.minute > 45).length;

  RandomSource _rng(MatchContext ctx, NarrationSlot slot) => Mix32Source(
    deriveSeed(ctx.seedPath.child(possession: slot.possession)),
  );
}

/// One side's draws, before the shared possession split is known.
class _SideStats {
  const _SideStats(
    this.goals,
    this.shots,
    this.onTarget,
    this.corners,
    this.cards,
  );

  final int goals;
  final ShotSplit shots;
  final int onTarget;
  final int corners;
  final DisciplineDraw cards;

  TeamMatchStats build(double possession) => TeamMatchStats(
    goals: goals,
    shots: shots.total,
    secondHalfShots: shots.secondHalf,
    shotsOnTarget: onTarget,
    corners: corners,
    fouls: cards.fouls,
    yellows: cards.yellows,
    reds: cards.reds,
    possessionPercent: possession,
  );
}
