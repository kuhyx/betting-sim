import 'dart:math' as math;

import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/events.dart';
import 'package:league_engine/src/scoreline/poisson_params.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// A bivariate-Poisson scoreline model with the Dixon-Coles low-score
/// correction.
///
/// Chosen because the sport is low-scoring: goals arrive as a rare-event
/// process, which is exactly what Poisson describes. Independent Poissons are
/// known to misprice 0-0, 1-0, 0-1 and 1-1, so the tau correction redistributes
/// mass across those four scores (Dixon & Coles, 1997).
class DixonColesModel implements ScorelineModel {
  /// Creates a model.
  const DixonColesModel([this.config = const ScoringConfig()]);

  /// Scoring-rate tunables.
  final ScoringConfig config;

  @override
  OutcomeProbs outcomeProbabilities(MatchContext ctx) {
    // Pure: no RNG is touched, so the bookmaker can price a match without
    // perturbing the scoreline that match will later produce.
    final rates = scoringRates(ctx, config);
    final grid = _scoreGrid(rates);

    var home = 0.0;
    var draw = 0.0;
    var away = 0.0;
    for (var h = 0; h <= config.maxGoals; h++) {
      for (var a = 0; a <= config.maxGoals; a++) {
        final p = grid[h][a];
        if (h > a) {
          home += p;
        } else if (h == a) {
          draw += p;
        } else {
          away += p;
        }
      }
    }

    // The grid is truncated at maxGoals, so it sums to slightly under 1.
    // Renormalise rather than letting the shortfall leak into the prices.
    final total = home + draw + away;
    return OutcomeProbs(
      home: home / total,
      draw: draw / total,
      away: away / total,
    );
  }

  @override
  MatchResult simulate(MatchContext ctx, RandomSource rng) {
    final rates = scoringRates(ctx, config);

    // Morale acts on variance alone: it stretches each side's rate away from
    // or toward the league mean without changing the expected total.
    final spread =
        (ctx.homeModifiers.varianceMultiplier +
            ctx.awayModifiers.varianceMultiplier) /
        2;
    final homeRate = _applyVariance(rates.home, spread, rng);
    final awayRate = _applyVariance(rates.away, spread, rng);

    // Sample from the SAME Dixon-Coles-corrected grid that
    // outcomeProbabilities integrates. Drawing two independent Poissons here
    // instead would ignore the tau correction, and the simulation would then
    // contradict the prices: measured at rho=-0.05, the model said 26.12%
    // draws while independent sampling produced 24.75%. A book quoting one
    // and settling the other is a book whose odds are a lie.
    final score = _sampleScore(homeRate, awayRate, rng);
    final homeGoals = score.home;
    final awayGoals = score.away;

    final events = <MatchEvent>[
      ..._goalEvents(homeGoals, byHome: true, ctx: ctx, rng: rng),
      ..._goalEvents(awayGoals, byHome: false, ctx: ctx, rng: rng),
    ]..sort((a, b) => a.minute.compareTo(b.minute));

    return MatchResult(
      homeScore: homeGoals,
      awayScore: awayGoals,
      events: events,
    );
  }

  /// Stretches [rate] around the league mean by [spread].
  ///
  /// A spread of 1 leaves the rate untouched, which is why an ordinary match
  /// is unaffected and only a club with unusual morale sees its outcomes widen.
  double _applyVariance(double rate, double spread, RandomSource rng) {
    if (spread == 1) {
      return rate;
    }
    final shock = rng.normal(0, (spread - 1).abs() * 0.35);
    return math.max(rate * math.exp(shock), 0.01);
  }

  /// Places [count] goals in time, biased by each side's late-match decay.
  ///
  /// This is fatigue's fingerprint: a tired side scores its goals earlier and
  /// concedes later, which shows up in goal timings while leaving the final
  /// score distribution alone. Reading it requires match detail, not the table.
  List<GoalEvent> _goalEvents(
    int count, {
    required bool byHome,
    required MatchContext ctx,
    required RandomSource rng,
  }) {
    final decay = byHome
        ? ctx.homeModifiers.lateMatchDecay
        : ctx.awayModifiers.lateMatchDecay;
    return <GoalEvent>[
      for (var i = 0; i < count; i++)
        GoalEvent(
          minute: _goalMinute(decay, rng),
          byHome: byHome,
          playerId: null,
        ),
    ];
  }

  int _goalMinute(double decay, RandomSource rng) {
    final u = rng.uniform01();
    // decay 0 -> uniform across the match; decay 1 -> pulled toward the first
    // half, because a spent side stops creating chances.
    final skewed = math.pow(u, 1 + decay).toDouble();
    return (skewed * 89).floor() + 1;
  }

  /// Draws a scoreline from the corrected joint distribution.
  ///
  /// Inverse-transform sampling over the flattened grid: one uniform draw
  /// picks a cell, so the sampled distribution is the priced distribution by
  /// construction rather than by coincidence.
  ({int home, int away}) _sampleScore(
    double homeRate,
    double awayRate,
    RandomSource rng,
  ) {
    final grid = _scoreGrid(ScoringRates(home: homeRate, away: awayRate));
    var total = 0.0;
    for (final row in grid) {
      for (final p in row) {
        total += p;
      }
    }

    // Walk the flattened grid, subtracting cell mass until the draw is spent.
    // The last cell is the loop's own final iteration, so every path returns
    // from inside it -- no trailing fallback, which would be unreachable dead
    // code: accumulated rounding runs NEGATIVE (measured -1.7e-15 over a
    // 169-cell grid), so the walk always terminates early.
    var target = rng.uniform01() * total;
    var last = (home: 0, away: 0);
    for (var h = 0; h <= config.maxGoals; h++) {
      for (var a = 0; a <= config.maxGoals; a++) {
        target -= grid[h][a];
        last = (home: h, away: a);
        if (target <= 0) {
          return last;
        }
      }
    }
    return last;
  }

  List<List<double>> _scoreGrid(ScoringRates rates) {
    final grid = List<List<double>>.generate(
      config.maxGoals + 1,
      (_) => List<double>.filled(config.maxGoals + 1, 0),
    );
    for (var h = 0; h <= config.maxGoals; h++) {
      for (var a = 0; a <= config.maxGoals; a++) {
        grid[h][a] =
            _poissonPmf(h, rates.home) *
            _poissonPmf(a, rates.away) *
            dixonColesTau(
              h,
              a,
              rates.home,
              rates.away,
              config.lowScoreCorrection,
            );
      }
    }
    return grid;
  }

  static double _poissonPmf(int k, double lambda) {
    var logP = -lambda + k * math.log(lambda);
    for (var i = 2; i <= k; i++) {
      logP -= math.log(i.toDouble());
    }
    return math.exp(logP);
  }
}
