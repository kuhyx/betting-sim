/// The player's running scoreboard: what the money did, and what the prices
/// say about whether it deserved to.
///
/// ROI and CLV answer different questions and both are needed to judge a
/// setting. ROI is the outcome and is dominated by variance over the handful
/// of bets a human strikes in one sitting; CLV compares two PRICES and so is
/// readable long before profit is. A player with positive CLV and a losing
/// night is unlucky; one with negative CLV and a winning night is not good.
///
/// Deliberately mutable and incremental rather than recomputed from history:
/// the debug panel reads it on every rebuild.
class Performance {
  /// An empty scoreboard.
  Performance();

  double _staked = 0;
  double _profit = 0;
  final List<double> _clvs = <double>[];

  /// How many bets have settled.
  int get bets => _clvs.length;

  /// Total staked.
  double get staked => _staked;

  /// Total profit, negative for a loss.
  double get profit => _profit;

  /// Return on stake, or null when nothing has been risked.
  ///
  /// Null rather than zero: no bets is not break-even, and showing 0.00%
  /// would read as "this setting is neutral" when it means "no data yet".
  ///
  /// This is POOLED profit over POOLED stake, which is the right statistic
  /// here and the wrong one for the acceptance gate. The gate averages
  /// per-season ROIs because its bettors stake Kelly fractions that compound,
  /// so pooling silently overweights winning seasons. A human picks from a
  /// fixed 5/10/25/50, and flat stakes make pooling honest.
  double? get roi => _staked == 0 ? null : _profit / _staked;

  /// Mean closing line value, or null when nothing has settled.
  double? get averageClv =>
      _clvs.isEmpty ? null : _clvs.reduce((a, b) => a + b) / _clvs.length;

  /// The fraction of bets that beat the closing line, or null when none have.
  ///
  /// A rate near 0.5 is what luck alone produces. Industry benchmarks: +1-2%
  /// mean CLV is sharp, +3% elite.
  double? get beatRate =>
      _clvs.isEmpty ? null : _clvs.where((c) => c > 0).length / _clvs.length;

  /// Records a settled bet.
  void record({
    required double stake,
    required double profit,
    required double clv,
  }) {
    _staked += stake;
    _profit += profit;
    _clvs.add(clv);
  }
}
