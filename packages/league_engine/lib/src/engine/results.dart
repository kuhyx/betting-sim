import 'package:league_engine/src/bettors/protocol.dart';

/// What one bet did, once the match was played.
class SettledBet {
  /// Creates a settled bet.
  const SettledBet({
    required this.bet,
    required this.profit,
    required this.closingLineValue,
  });

  /// The bet as placed.
  final Bet bet;

  /// Profit, negative for a loss.
  final double profit;

  /// How the price taken compared with the closing line.
  final double closingLineValue;
}

/// One matchday's betting.
class MatchdayResult {
  /// Creates a matchday result.
  const MatchdayResult({required this.day, required this.bets});

  /// Which matchday.
  final int day;

  /// Every bet settled on it.
  final List<SettledBet> bets;

  /// Total staked.
  double get staked => bets.fold(0, (sum, b) => sum + b.bet.stake);

  /// Total profit.
  double get profit => bets.fold(0, (sum, b) => sum + b.profit);

  /// Return on stake, or null when nothing was risked.
  ///
  /// Null rather than zero on purpose: a matchday with no bet is not a
  /// break-even matchday, and averaging it in as one would quietly drag every
  /// statistic toward zero.
  double? get roi => staked == 0 ? null : profit / staked;
}

/// A whole season's betting.
class SeasonResult {
  /// Creates a season result.
  const SeasonResult({required this.matchdays, required this.bettorName});

  /// Every matchday, in order.
  final List<MatchdayResult> matchdays;

  /// Which strategy produced it.
  final String bettorName;

  /// Every settled bet in the season.
  List<SettledBet> get bets => <SettledBet>[
    for (final d in matchdays) ...d.bets,
  ];

  /// Total staked across the season.
  double get staked => matchdays.fold(0, (sum, d) => sum + d.staked);

  /// Total profit across the season.
  double get profit => matchdays.fold(0, (sum, d) => sum + d.profit);

  /// Return on stake for the season.
  double get roi => staked == 0 ? 0 : profit / staked;

  /// Matchdays on which at least one bet was struck.
  ///
  /// Gate 2 is computed over these only. A strategy that declines thin edges
  /// sits out many nights, and counting those as ROI 0 would swamp the median
  /// and drag the losing-night fraction toward the bet frequency instead of
  /// measuring risk.
  List<MatchdayResult> get activeMatchdays =>
      matchdays.where((d) => d.bets.isNotEmpty).toList();

  /// The share of matchdays on which a bet was struck.
  double get betFrequency =>
      matchdays.isEmpty ? 0 : activeMatchdays.length / matchdays.length;
}
