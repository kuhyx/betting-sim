import 'package:league_engine/src/book/margin.dart';
import 'package:league_engine/src/book/odds.dart';
import 'package:league_engine/src/book/pricing.dart';

/// Closing Line Value: did you take a better price than the market closed at?
///
/// The canonical measure of betting skill, and the game's own scoreboard.
/// Because it compares two PRICES rather than waiting on results, it is
/// readable long before profit is: a player with positive CLV and a losing
/// month is unlucky, and one with negative CLV and a winning month is not good.
///
/// Industry benchmarks the game teaches against: +1-2% is sharp, +3% elite,
/// and a beat-rate near 50% means no edge at all.
class ClvCalculator {
  /// Creates a calculator.
  const ClvCalculator();

  /// CLV for a single bet, as a fraction.
  ///
  /// Both prices have their margin stripped first: comparing raw quoted odds
  /// would measure the book's margin as though it were the player's skill.
  double forBet({
    required Selection selection,
    required Odds taken,
    required Market closing,
  }) {
    final takenFair = _fairProbability(selection, taken, closing);
    final closingFair = closing.fairProbabilities[selection.index];
    return closingFair / takenFair - 1;
  }

  /// The no-vig probability implied by the price actually taken.
  ///
  /// Uses the closing market's shape to apportion the margin, since a single
  /// price carries no information about the rest of its market.
  double _fairProbability(Selection selection, Odds taken, Market closing) {
    final implied = List<double>.of(closing.impliedProbabilities);
    implied[selection.index] = taken.impliedProbability;
    return removeVig(implied)[selection.index];
  }

  /// Mean CLV across many bets.
  double average(List<double> clvs) =>
      clvs.isEmpty ? 0 : clvs.reduce((a, b) => a + b) / clvs.length;

  /// The fraction of bets that beat the closing line.
  ///
  /// A rate near 0.5 is what luck alone produces.
  double beatRate(List<double> clvs) =>
      clvs.isEmpty ? 0 : clvs.where((c) => c > 0).length / clvs.length;
}
