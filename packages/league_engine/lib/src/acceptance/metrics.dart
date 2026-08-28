import 'dart:math' as math;

import 'package:league_engine/src/engine/results.dart';

/// Summary statistics for one strategy across many seasons.
class StrategyMetrics {
  /// Creates metrics.
  const StrategyMetrics({
    required this.name,
    required this.seasons,
    required this.meanSeasonRoi,
    required this.standardError,
    required this.medianMatchdayRoi,
    required this.losingNightFraction,
    required this.activeMatchdays,
    required this.betFrequency,
    required this.meanClv,
    required this.beatRate,
  });

  /// Which strategy.
  final String name;

  /// How many seasons were simulated.
  final int seasons;

  /// Mean of the per-season ROIs.
  ///
  /// Deliberately NOT pooled profit over pooled stake. Kelly staking
  /// compounds, so a winning season stakes several times what a losing one
  /// does and a pooled figure silently overweights the good ones -- measured
  /// at +0.79% pooled against a -2.1% median season.
  final double meanSeasonRoi;

  /// Standard error of [meanSeasonRoi].
  final double standardError;

  /// Median ROI across matchdays on which a bet was struck.
  final double medianMatchdayRoi;

  /// Fraction of active matchdays that lost money.
  final double losingNightFraction;

  /// How many matchdays saw at least one bet.
  final int activeMatchdays;

  /// Share of all matchdays on which a bet was struck.
  final double betFrequency;

  /// Mean closing-line value.
  final double meanClv;

  /// Share of bets that beat the closing line.
  final double beatRate;

  /// The 95% confidence interval on [meanSeasonRoi].
  ({double low, double high}) get confidenceInterval => (
    low: meanSeasonRoi - 1.96 * standardError,
    high: meanSeasonRoi + 1.96 * standardError,
  );
}

/// Reduces raw season results to [StrategyMetrics].
StrategyMetrics summarise(String name, List<SeasonResult> seasons) {
  final seasonRois = <double>[for (final s in seasons) s.roi];
  final mean = _mean(seasonRois);

  // Gate 2 counts only matchdays where a bet was struck. Counting a no-bet
  // night as ROI 0 would swamp the median and drag the losing-night fraction
  // toward the bet frequency rather than measuring risk.
  final dayRois = <double>[
    for (final s in seasons)
      for (final d in s.activeMatchdays)
        if (d.roi case final r?) r,
  ]..sort();

  final clvs = <double>[
    for (final s in seasons)
      for (final b in s.bets) b.closingLineValue,
  ];

  final activeDays = seasons.fold(0, (n, s) => n + s.activeMatchdays.length);
  final totalDays = seasons.fold(0, (n, s) => n + s.matchdays.length);

  return StrategyMetrics(
    name: name,
    seasons: seasons.length,
    meanSeasonRoi: mean,
    standardError: _standardError(seasonRois, mean),
    medianMatchdayRoi: dayRois.isEmpty ? 0 : dayRois[dayRois.length ~/ 2],
    losingNightFraction: dayRois.isEmpty
        ? 0
        : dayRois.where((r) => r < 0).length / dayRois.length,
    activeMatchdays: activeDays,
    betFrequency: totalDays == 0 ? 0 : activeDays / totalDays,
    meanClv: _mean(clvs),
    beatRate: clvs.isEmpty ? 0 : clvs.where((c) => c > 0).length / clvs.length,
  );
}

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

double _standardError(List<double> xs, double mean) {
  if (xs.length < 2) {
    return 0;
  }
  var sumSq = 0.0;
  for (final x in xs) {
    sumSq += (x - mean) * (x - mean);
  }
  return math.sqrt(sumSq / (xs.length - 1)) / math.sqrt(xs.length);
}
