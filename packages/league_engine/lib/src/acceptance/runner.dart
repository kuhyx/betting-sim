import 'package:league_engine/src/acceptance/gate.dart';
import 'package:league_engine/src/acceptance/metrics.dart';
import 'package:league_engine/src/bettors/oracle_bettor.dart';
import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/bettors/random_bettor.dart';
import 'package:league_engine/src/bettors/skilled_bettor.dart';
import 'package:league_engine/src/book/margin.dart';
import 'package:league_engine/src/book/opening.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/engine/results.dart';
import 'package:league_engine/src/engine/season_runner.dart';

/// The outcome of an acceptance run.
class AcceptanceReport {
  /// Creates a report.
  const AcceptanceReport({
    required this.strategies,
    required this.gates,
    required this.margin,
    required this.masterSeed,
    required this.seasons,
  });

  /// Metrics for every strategy, in report order.
  final List<StrategyMetrics> strategies;

  /// Every gate's verdict.
  final List<GateResult> gates;

  /// The book's margin.
  final double margin;

  /// The base seed the run started from.
  final int masterSeed;

  /// How many seasons were simulated per strategy.
  final int seasons;

  /// Whether every gate held.
  bool get passed => gates.every((g) => g.passed);
}

/// Simulates [seasons] seasons for each strategy and runs the gates.
///
/// The oracle is included as a HEADROOM CONTROL rather than a subject: if even
/// perfect knowledge cannot clear the margin, the game is unwinnable and no
/// tuning of the skilled bettor could fix it. It answers "is gate 1 reachable"
/// before we ask "does this strategy reach it".
AcceptanceReport runAcceptance({
  int seasons = 200,
  int masterSeed = 9000,
  double margin = 0.05,
  SeasonRunner? runner,
}) {
  final engine =
      runner ??
      SeasonRunner(
        bookmaker: Bookmaker(marginMethod: ProportionalMargin(margin)),
      );

  final bettors = <Bettor>[
    const SkilledBettor(),
    const RandomBettor(),
    const OracleBettor(),
  ];

  final metrics = <StrategyMetrics>[];
  for (final bettor in bettors) {
    final results = <SeasonResult>[
      for (var i = 0; i < seasons; i++)
        engine.run(masterSeed: masterSeed + i, bettor: bettor),
    ];
    metrics.add(summarise(bettor.name, results));
  }

  // Gate 3a needs a deliberately infallible book: one that prices the truth
  // with no estimation error at all. That is the only condition under which
  // -v/(1+v) is exact, so it is the only fair test of the pricing maths.
  final perfectBook = SeasonRunner(
    bookmaker: Bookmaker(marginMethod: ProportionalMargin(margin)),
    bookLatentAwareness: 1,
    openingLine: const OpeningLine(baseNoise: 0, uncertaintyWeight: 0),
  );
  final randomVsPerfect = summarise(
    'random-vs-perfect',
    <SeasonResult>[
      for (var i = 0; i < seasons; i++)
        perfectBook.run(
          masterSeed: masterSeed + i,
          bettor: const RandomBettor(),
        ),
    ],
  );

  final skilled = metrics.firstWhere((m) => m.name == 'skilled');
  final random = metrics.firstWhere((m) => m.name == 'random');

  return AcceptanceReport(
    strategies: [...metrics, randomVsPerfect],
    gates: runGates(
      skilled: skilled,
      random: random,
      randomVsPerfectBook: randomVsPerfect,
      margin: margin,
    ),
    margin: margin,
    masterSeed: masterSeed,
    seasons: seasons,
  );
}

/// Renders [report] as the text the gate script prints.
String formatReport(AcceptanceReport report, Duration elapsed) {
  final buffer = StringBuffer()
    ..writeln('betting-sim acceptance gate')
    ..writeln(
      'seasons: ${report.seasons} per strategy   '
      'master-seed: ${report.masterSeed}   '
      'margin: ${_pct(report.margin)}   '
      'wall: ${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
    )
    ..writeln();

  for (final m in report.strategies) {
    buffer.writeln(
      '${m.name.padRight(8)} '
      'season ROI ${_pct(m.meanSeasonRoi).padLeft(8)}  '
      'CLV ${_pct(m.meanClv).padLeft(7)}  '
      'beat ${_pct(m.beatRate).padLeft(7)}  '
      'bet on ${_pct(m.betFrequency)} of days',
    );
  }
  buffer.writeln();

  report.gates.forEach(buffer.writeln);
  buffer
    ..writeln()
    ..writeln(report.passed ? 'ALL GATES PASSED' : 'GATES FAILED');
  return buffer.toString();
}

String _pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
