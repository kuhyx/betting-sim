import 'package:league_engine/src/acceptance/gate.dart';
import 'package:league_engine/src/acceptance/metrics.dart';
import 'package:league_engine/src/life/life_runner.dart';
import 'package:league_engine/src/life/needs.dart';

/// Thresholds for the life gate.
class LifeGateConfig {
  /// Creates a config.
  const LifeGateConfig({this.minRentToEdgeRatio = 10});

  /// How many times a season's rent must exceed a season's best betting
  /// return, on the money you start with.
  ///
  /// Ten is not a close call, and it is not meant to be. The number exists to
  /// say something structural -- a bankroll is not an income -- rather than to
  /// balance anything.
  final double minRentToEdgeRatio;
}

/// Gate 6a: a working life is affordable.
///
/// Somebody who works their shifts, eats, and sleeps must reach the end of the
/// season housed and solvent. If the person doing everything right cannot make
/// rent, the numbers are wrong, and no amount of clever betting would be a fix
/// -- it would just be the only option, which is the opposite of a stake.
///
/// It is deliberately TIGHT. The grafter ends a season a little down on where
/// they started: the job keeps a roof on, and the betting is how you actually
/// get anywhere.
GateResult gateAWorkingLifeIsAffordable(LifeResult grafter) {
  final passed =
      grafter.survived &&
      !grafter.everStarved &&
      grafter.household.bankroll > 0 &&
      !grafter.needs.exhausted;
  return GateResult(
    name: 'gate 6a: a working life is affordable',
    passed: passed,
    detail:
        'the grafter finished ${grafter.household.ending.name} on '
        '${grafter.household.bankroll.toStringAsFixed(0)}, '
        'energy ${grafter.needs.energy.toStringAsFixed(2)}',
  );
}

/// Gate 6b: betting is not a living.
///
/// A season's rent must dwarf what even PERFECT knowledge returns on the money
/// you start with. This is the gate that gives the bankroll a floor worth
/// fearing: the oracle's whole season of cheating is worth a few weeks' rent,
/// so the answer to "can I just bet for a living" is arithmetic rather than
/// opinion.
///
/// [idler] is the demonstration rather than the assertion -- somebody who
/// stops working is put out well before the season ends.
GateResult gateBettingIsNotALiving(
  StrategyMetrics oracle,
  LifeResult idler, {
  double openingBankroll = 1000,
  LifeConfig config = const LifeConfig(),
  int weeks = 38,
  LifeGateConfig gateConfig = const LifeGateConfig(),
}) {
  final rent = config.rentPerWeek * weeks;
  final bestEdge = oracle.meanSeasonRoi * openingBankroll;
  final ratio = rent / bestEdge;
  final passed = ratio > gateConfig.minRentToEdgeRatio && !idler.survived;
  return GateResult(
    name: 'gate 6b: betting is not a living',
    passed: passed,
    detail:
        'a season of rent is ${rent.toStringAsFixed(0)} against the oracle’s '
        '${bestEdge.toStringAsFixed(0)} (${ratio.toStringAsFixed(0)}x); '
        'the idler was ${idler.household.ending.name} on day '
        '${idler.daysLived}',
  );
}
