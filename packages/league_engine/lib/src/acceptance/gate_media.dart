import 'package:league_engine/src/acceptance/gate.dart';
import 'package:league_engine/src/acceptance/metrics.dart';

/// Thresholds for the feed gate.
class MediaGateConfig {
  /// Creates a config.
  const MediaGateConfig({this.maxInsiderShare = 0.6});

  /// The most of the oracle's edge that following one tipster may capture.
  ///
  /// A cap, not a target. The feed is meant to be a second way to earn an
  /// edge, not a shortcut past the hidden state: if reading the right account
  /// approached what perfect knowledge is worth, nobody would ever study a
  /// fixture list again.
  final double maxInsiderShare;
}

/// Gate 4a: the crowd is not an edge.
///
/// Following the loudest voices must LOSE, at roughly the rate a random
/// bettor loses. This is the gate that keeps the feed a puzzle rather than a
/// hint system, and it has already caught one build: with independent errors
/// only, averaging twelve opinions cancelled the noise and left the truth, so
/// the consensus returned +12.8%. A shared per-fixture narrative -- everybody
/// having read the same story -- is what fixed it.
GateResult gateTheCrowdIsNotAnEdge(StrategyMetrics crowd) {
  final passed = crowd.meanSeasonRoi < 0;
  return GateResult(
    name: 'gate 4a: the crowd is not an edge',
    passed: passed,
    detail:
        'following the loudest tips returns '
        '${_pct(crowd.meanSeasonRoi)} per season',
  );
}

/// Gate 4b: there is something in the feed worth finding.
///
/// The mirror of 4a, and it needs both halves. If nobody on the panel can beat
/// the market, keeping records is busywork and the feed is decoration; if
/// following one account rivals perfect knowledge, the hidden state stops
/// mattering. [insider] is a CONTROL in the same sense as the oracle: it is
/// TOLD which tipster is sharp, and a player never is.
GateResult gateTheFeedIsWorthReading(
  StrategyMetrics insider,
  StrategyMetrics crowd,
  StrategyMetrics oracle, [
  MediaGateConfig config = const MediaGateConfig(),
]) {
  final ceiling = oracle.meanSeasonRoi * config.maxInsiderShare;
  final passed =
      insider.meanSeasonRoi > 0 &&
      insider.meanSeasonRoi > crowd.meanSeasonRoi &&
      insider.meanSeasonRoi < ceiling;
  return GateResult(
    name: 'gate 4b: the feed is worth reading',
    passed: passed,
    detail:
        'the sharpest tipster returns ${_pct(insider.meanSeasonRoi)} '
        "against the crowd's ${_pct(crowd.meanSeasonRoi)}, "
        'under the ${_pct(ceiling)} ceiling',
  );
}

String _pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
