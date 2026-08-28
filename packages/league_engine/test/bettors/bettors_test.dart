import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

BettingView _view({
  double margin = 0.05,
  double? homeFatigue,
  double? awayFatigue,
  double limit = 500,
}) {
  final league = generateLeague(20260828);
  const mr = MatchRunner(model: DixonColesModel());
  final ctx = mr.contextFor(
    home: league.teams[0],
    away: league.teams[1],
    homeState: const LatentState(),
    awayState: const LatentState(),
    seedPath: const SeedPath(master: 1, season: 0, day: 0, match: 0),
  );
  final market = Bookmaker(marginMethod: ProportionalMargin(margin))
      .price(const DixonColesModel().outcomeProbabilities(ctx), limit: limit);
  return BettingView(
    market: market,
    context: ctx,
    observedHomeFatigue: homeFatigue,
    observedAwayFatigue: awayFatigue,
  );
}

/// A market whose prices disagree with the truth, so an edge exists.
BettingView _mispriced({double limit = 500}) {
  final league = generateLeague(20260828);
  const mr = MatchRunner(model: DixonColesModel());
  final ctx = mr.contextFor(
    home: league.teams[0],
    away: league.teams[1],
    homeState: const LatentState(),
    awayState: const LatentState(),
    seedPath: const SeedPath(master: 1, season: 0, day: 0, match: 0),
  );
  // Price a deliberately wrong opinion: an even three-way market on a fixture
  // the model does not think is even.
  final market = const Bookmaker(marginMethod: ProportionalMargin(0.01)).price(
    const OutcomeProbs(home: 1 / 3, draw: 1 / 3, away: 1 / 3),
    limit: limit,
  );
  return BettingView(market: market, context: ctx);
}

void main() {
  group('kellyFraction', () {
    test('stakes nothing without an edge', () {
      // The single most important discipline the game teaches.
      expect(
        kellyFraction(probability: 0.4, odds: const Odds(2)),
        0,
      );
      expect(
        kellyFraction(probability: 0.5, odds: const Odds(2)),
        0,
        reason: 'a fair price is not an edge',
      );
    });

    test('stakes more as the edge grows', () {
      final small = kellyFraction(probability: 0.55, odds: const Odds(2));
      final large = kellyFraction(probability: 0.70, odds: const Odds(2));
      expect(large, greaterThan(small));
    });

    test('quarter-Kelly stakes a quarter of full Kelly', () {
      // Full Kelly maximises growth but routinely halves a bankroll, which is
      // why practitioners bet a fraction of it.
      final full = kellyFraction(
        probability: 0.6,
        odds: const Odds(2),
        fraction: 1,
      );
      final quarter = kellyFraction(probability: 0.6, odds: const Odds(2));
      expect(quarter, closeTo(full / 4, 1e-12));
    });

    test('matches the textbook formula', () {
      // f* = (bp - q)/b with b=1, p=0.6 -> 0.2
      expect(
        kellyFraction(probability: 0.6, odds: const Odds(2), fraction: 1),
        closeTo(0.2, 1e-12),
      );
    });
  });

  group('settle', () {
    const home = MatchResult(homeScore: 2, awayScore: 0, events: []);
    const draw = MatchResult(homeScore: 1, awayScore: 1, events: []);
    const away = MatchResult(homeScore: 0, awayScore: 2, events: []);

    test('pays a winning selection and takes a losing stake', () {
      const bet = Bet(selection: Selection.home, stake: 10, taken: Odds(2.5));
      expect(settle(bet, home), closeTo(15, 1e-12));
      expect(settle(bet, draw), -10);
      expect(settle(bet, away), -10);
    });

    test('settles draws and away wins', () {
      const onDraw = Bet(selection: Selection.draw, stake: 10, taken: Odds(3));
      const onAway = Bet(selection: Selection.away, stake: 10, taken: Odds(4));
      expect(settle(onDraw, draw), closeTo(20, 1e-12));
      expect(settle(onDraw, home), -10);
      expect(settle(onAway, away), closeTo(30, 1e-12));
      expect(settle(onAway, draw), -10);
    });
  });

  group('RandomBettor', () {
    test('always backs exactly one outcome', () {
      const bettor = RandomBettor();
      final rng = Mix32Source(3);
      for (var i = 0; i < 100; i++) {
        expect(bettor.betsFor(_view(), 1000, rng), hasLength(1));
      }
    });

    test('reaches every selection', () {
      const bettor = RandomBettor();
      final rng = Mix32Source(3);
      final seen = <Selection>{};
      for (var i = 0; i < 200; i++) {
        seen.add(bettor.betsFor(_view(), 1000, rng).single.selection);
      }
      expect(seen, hasLength(3));
    });

    test('respects the book limit', () {
      const bettor = RandomBettor(stake: 900);
      final bet = bettor
          .betsFor(_view(limit: 25), 10000, Mix32Source(1))
          .single;
      expect(bet.stake, 25);
    });

    test('is named for the report', () {
      expect(const RandomBettor().name, 'random');
    });
  });

  group('OracleBettor', () {
    test('declines when the price offers no edge', () {
      // Even perfect knowledge must clear the margin first.
      final bets = const OracleBettor(edgeThreshold: 0.5)
          .betsFor(_view(), 1000, Mix32Source(1));
      expect(bets, isEmpty);
    });

    test('declines a market priced from the truth, however thin', () {
      // Worth stating plainly: against a book that prices the truth exactly,
      // even an oracle has expected value -v/(1+v) on every selection.
      // Perfect knowledge is NOT an edge -- an edge requires the book to be
      // wrong. This is why the skilled bettor is built around an information
      // gap rather than around better arithmetic.
      for (final margin in <double>[0.05, 0.01, 0.001]) {
        expect(
          const OracleBettor(
            edgeThreshold: 0,
          ).betsFor(_view(margin: margin), 1000, Mix32Source(1)),
          isEmpty,
          reason: 'margin $margin',
        );
      }
    });

    test('backs a mispriced market and respects the limit', () {
      final bets = const OracleBettor().betsFor(
        _mispriced(limit: 3),
        100000,
        Mix32Source(1),
      );
      expect(bets, isNotEmpty);
      for (final b in bets) {
        expect(b.stake, lessThanOrEqualTo(3));
      }
    });

    test('is named for the report', () {
      expect(const OracleBettor().name, 'oracle');
    });
  });

  group('SkilledBettor', () {
    test('falls back to the book opinion with nothing observed', () {
      // No information gap, no reason to disagree with the price.
      final bets = const SkilledBettor().betsFor(_view(), 1000, Mix32Source(1));
      expect(bets, isEmpty);
    });

    test('disagrees with the book once it observes fatigue', () {
      final bets = const SkilledBettor(edgeThreshold: 0).betsFor(
        _view(margin: 0.001, homeFatigue: 0.9),
        1000,
        Mix32Source(1),
      );
      expect(bets, isNotEmpty);
    });

    test('declines thin edges', () {
      final bets = const SkilledBettor(edgeThreshold: 0.9).betsFor(
        _view(homeFatigue: 0.9),
        1000,
        Mix32Source(1),
      );
      expect(bets, isEmpty);
    });

    test('never reads the true probabilities', () {
      // The whole point: an oracle beats any book by construction and would
      // make the acceptance gate a rubber stamp.
      final withoutInfo = const SkilledBettor(edgeThreshold: 0)
          .betsFor(_view(margin: 0.001), 1000, Mix32Source(1));
      expect(withoutInfo, isEmpty);
    });

    test('is named for the report', () {
      expect(const SkilledBettor().name, 'skilled');
    });
  });

  group('Bet', () {
    test('computes its potential profit', () {
      const bet = Bet(selection: Selection.home, stake: 20, taken: Odds(3));
      expect(bet.potentialProfit, closeTo(40, 1e-12));
    });

    test('describes itself', () {
      const bet = Bet(selection: Selection.draw, stake: 5, taken: Odds(3.5));
      expect(bet.toString(), 'Bet(draw 5.0 @ 3.50)');
    });
  });
}
