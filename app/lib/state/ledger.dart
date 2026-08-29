import 'package:league_engine/league_engine.dart';

/// What one tipster has actually done, as far as you have bothered to check.
class TipsterRecord {
  /// Creates a record.
  const TipsterRecord({
    this.tips = 0,
    this.hits = 0,
    this.profit = 0,
    this.staked = 0,
  });

  /// How many calls of theirs you have seen settle.
  final int tips;

  /// How many came in.
  final int hits;

  /// What a flat stake on every one of them would have returned.
  final double profit;

  /// What a flat stake on every one of them would have risked.
  final double staked;

  /// The share that won. Null until they have said anything.
  double? get strikeRate => tips == 0 ? null : hits / tips;

  /// Return on stake for blindly following them. Null until they have.
  ///
  /// The number that actually matters, and the one a strike rate hides: a
  /// tipster who only ever backs odds-on favourites can be right most weeks
  /// and still lose you money.
  double? get roi => staked == 0 ? null : profit / staked;

  /// This record with one more settled call folded in.
  TipsterRecord plus({
    required bool won,
    required double stake,
    required double returned,
  }) => TipsterRecord(
    tips: tips + 1,
    hits: hits + (won ? 1 : 0),
    profit: profit + returned - stake,
    staked: staked + stake,
  );
}

/// The notebook: who said what, and whether it came in.
///
/// The whole tipster mechanic lives here. The game never marks anybody as
/// sharp -- confidence is drawn independently of skill, so the feed cannot be
/// read at a glance. The only way to find the two people on the panel worth
/// following is to write down what they said and check later, which is what
/// this does on your behalf.
class TipsterLedger {
  /// An empty notebook.
  TipsterLedger();

  final Map<int, TipsterRecord> _records = <int, TipsterRecord>{};

  /// What you have on [tipsterId] so far.
  TipsterRecord recordFor(int tipsterId) =>
      _records[tipsterId] ?? const TipsterRecord();

  /// Every tipster you have anything on, best return first.
  ///
  /// Sorted by what following them would have RETURNED rather than by how
  /// often they were right, and ties broken by id so the order is stable
  /// across rebuilds.
  List<({int tipsterId, TipsterRecord record})> get standings {
    final rows =
        <({int tipsterId, TipsterRecord record})>[
          for (final e in _records.entries) (tipsterId: e.key, record: e.value),
        ]..sort((a, b) {
          final byRoi = (b.record.roi ?? 0).compareTo(a.record.roi ?? 0);
          return byRoi != 0 ? byRoi : a.tipsterId.compareTo(b.tipsterId);
        });
    return rows;
  }

  /// Folds a matchday's tips into the notebook, at a flat [stake] each.
  void record(
    List<Tip> tips,
    MatchResult result,
    Market market, {
    double stake = 10,
  }) {
    for (final tip in tips) {
      final bet = Bet(
        selection: tip.selection,
        stake: stake,
        taken: market.priceOf(tip.selection),
      );
      final profit = settle(bet, result);
      _records[tip.tipsterId] = recordFor(tip.tipsterId).plus(
        won: profit > 0,
        stake: stake,
        returned: stake + profit,
      );
    }
  }
}
