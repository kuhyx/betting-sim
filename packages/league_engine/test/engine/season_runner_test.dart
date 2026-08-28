import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const runner = SeasonRunner();
  const smallLeague = LeagueConfig(teamCount: 6, squadSize: 6);

  group('SeasonRunner', () {
    test('plays every matchday of the season', () {
      final result = runner.run(
        masterSeed: 42,
        bettor: const RandomBettor(),
        leagueConfig: smallLeague,
      );
      expect(result.matchdays, hasLength(10));
      expect(result.bettorName, 'random');
    });

    test('is deterministic: one seed, one season', () {
      SeasonResult play() => runner.run(
        masterSeed: 42,
        bettor: const RandomBettor(),
        leagueConfig: smallLeague,
      );
      final a = play();
      final b = play();
      expect(b.profit, a.profit);
      expect(b.staked, a.staked);
      expect(b.bets.length, a.bets.length);
    });

    test('different seeds give different seasons', () {
      double profitFor(int seed) => runner
          .run(
            masterSeed: seed,
            bettor: const RandomBettor(),
            leagueConfig: smallLeague,
          )
          .profit;
      expect(profitFor(1), isNot(profitFor(2)));
    });

    test('a random bettor backs every match', () {
      final result = runner.run(
        masterSeed: 42,
        bettor: const RandomBettor(),
        leagueConfig: smallLeague,
      );
      expect(result.bets, hasLength(30));
      expect(result.betFrequency, 1);
    });

    test('records closing-line value for every bet', () {
      final result = runner.run(
        masterSeed: 42,
        bettor: const RandomBettor(),
        leagueConfig: smallLeague,
      );
      for (final b in result.bets) {
        expect(b.closingLineValue.isFinite, isTrue);
      }
    });

    test('a perfectly informed book leaves a random bettor no value', () {
      // The invariant behind gate 3a: against a book that prices the truth
      // with no error, closing-line value is exactly zero for everyone.
      const perfect = SeasonRunner(
        bookLatentAwareness: 1,
        openingLine: OpeningLine(baseNoise: 0, uncertaintyWeight: 0),
      );
      final result = perfect.run(
        masterSeed: 42,
        bettor: const RandomBettor(),
        leagueConfig: smallLeague,
      );
      final mean =
          result.bets.map((b) => b.closingLineValue).reduce((a, b) => a + b) /
          result.bets.length;
      expect(mean, closeTo(0, 0.01));
    });

    test('a blind book leaves value on the table', () {
      // Measured over 40 seasons rather than one: the edge is thin by design,
      // so a single season is dominated by variance. Asserting on bet COUNT
      // does not work -- the threshold gates on edge size, not frequency.
      double meanRoi(double awareness) {
        final engine = SeasonRunner(bookLatentAwareness: awareness);
        var total = 0.0;
        for (var s = 0; s < 40; s++) {
          total += engine
              .run(masterSeed: 500 + s, bettor: const SkilledBettor())
              .roi;
        }
        return total / 40;
      }

      expect(meanRoi(0.5), greaterThan(meanRoi(1)));
    });

    test('midweek fixtures make clubs differently tired', () {
      // Without them every club plays every matchday, fatigue is identical
      // across the league and studying the fixture list is worthless.
      const noCongestion = SeasonRunner(midweekFixtureRate: 0);
      const congested = SeasonRunner(midweekFixtureRate: 1);
      final flat = noCongestion.run(
        masterSeed: 42,
        bettor: const SkilledBettor(),
        leagueConfig: smallLeague,
      );
      final varied = congested.run(
        masterSeed: 42,
        bettor: const SkilledBettor(),
        leagueConfig: smallLeague,
      );
      expect(varied.staked, isNot(flat.staked));
    });

    test('a bettor that declines everything still completes the season', () {
      final result = runner.run(
        masterSeed: 42,
        bettor: const SkilledBettor(edgeThreshold: 10),
        leagueConfig: smallLeague,
      );
      expect(result.matchdays, hasLength(10));
      expect(result.bets, isEmpty);
      expect(result.roi, 0);
      expect(result.betFrequency, 0);
    });
  });
}
