import 'package:league_engine/src/acceptance/gate.dart';
import 'package:league_engine/src/acceptance/metrics.dart';

/// Thresholds for the friends gate.
class SocialGateConfig {
  /// Creates a config.
  const SocialGateConfig({this.maxShrewdShare = 0.6});

  /// The most of the oracle's edge that beating your friends may capture.
  ///
  /// A cap, not a target. Peer betting is meant to be a second table, not a
  /// way around the bookmaker: if turning over your mates paid what perfect
  /// knowledge pays, the market would stop mattering.
  final double maxShrewdShare;
}

/// Gate 5a: your friends are cheaper than the bookmaker, and still not free.
///
/// A friend asks a price that is fair BY THEIR OWN LIGHTS, with no margin in
/// it, so saying yes to everything ought to cost less than the vig. It should
/// not cost NOTHING, and the reason it does not is worth stating: friends
/// price off the published line, so they inherit the book's blind spots, and
/// an indiscriminate layer ends up taking the wrong side of exactly the
/// errors a studious player is trying to back. Measured at about half what
/// the book charges.
///
/// Both bounds matter. Above zero and peer betting is a money printer that
/// makes the market pointless; below the book's own rate and "bet with your
/// mates" is just a worse bookmaker wearing a friendlier hat.
GateResult gateFriendsAreCheaperThanTheBook(
  StrategyMetrics acceptAll,
  double margin,
) {
  final vig = -margin / (1 + margin);
  final roi = acceptAll.meanSeasonRoi;
  final passed = roi < 0 && roi > vig;
  return GateResult(
    name: 'gate 5a: friends charge less than the book, and more than nothing',
    passed: passed,
    detail:
        'saying yes to everything returns ${_pct(roi)}, '
        'between the book’s ${_pct(vig)} and zero',
  );
}

/// Gate 5b: choosing which to accept is an edge.
///
/// The half that makes the friends tab a game rather than a chore. A reviewer
/// that reads the fixture the way a studious player does must beat one that
/// says yes to everything, must clear zero, and must stay under a share of
/// what perfect knowledge is worth.
GateResult gateChoosingBeatsAccepting(
  StrategyMetrics shrewd,
  StrategyMetrics acceptAll,
  StrategyMetrics oracle, [
  SocialGateConfig config = const SocialGateConfig(),
]) {
  final ceiling = oracle.meanSeasonRoi * config.maxShrewdShare;
  final passed =
      shrewd.meanSeasonRoi > 0 &&
      shrewd.meanSeasonRoi > acceptAll.meanSeasonRoi &&
      shrewd.meanSeasonRoi < ceiling;
  return GateResult(
    name: 'gate 5b: choosing beats accepting',
    passed: passed,
    detail:
        'picking your spots returns ${_pct(shrewd.meanSeasonRoi)} '
        'against ${_pct(acceptAll.meanSeasonRoi)} for taking everything, '
        'under the ${_pct(ceiling)} ceiling',
  );
}

String _pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
