import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

const _day = SeedPath(master: 7, season: 0, day: 3);

/// One club's roll and its effect, wired the way the round loops do it.
LatentState _afterMatch(
  InjuryClock clock,
  LatentConfig config,
  LatentState state,
  int clubId,
) {
  final hurt = LatentShocks(config)
      .rollInjury(state, clock.rngFor(day: _day, clubId: clubId));
  return clock.afterMatch(state, hurt: hurt);
}

void main() {
  group('InjuryClock', () {
    test('a certain injury puts one player out with a fresh clock', () {
      const config = LatentConfig(injuryBaseRate: 1);
      final next = _afterMatch(
        const InjuryClock(config),
        config,
        const LatentState(),
        4,
      );
      expect(next.injuredCount, 1);
      expect(next.injuryDays, 0);
    });

    test('an impossible injury leaves the club alone', () {
      const config = LatentConfig(injuryBaseRate: 0, injuryFatigueScaling: 0);
      final next = _afterMatch(
        const InjuryClock(config),
        config,
        const LatentState(),
        4,
      );
      expect(next.injuredCount, 0);
    });

    test('the injury list is capped', () {
      const config = LatentConfig(injuryBaseRate: 1);
      const clock = InjuryClock(config);
      var state = const LatentState();
      for (var i = 0; i < 20; i++) {
        state = _afterMatch(clock, config, state, 4);
      }
      expect(state.injuredCount, const LatentConfig().maxInjured);
    });

    test('the same club on the same day rolls the same way', () {
      const config = LatentConfig(injuryBaseRate: 0.5);
      const clock = InjuryClock(config);
      int roll(int club) =>
          _afterMatch(clock, config, const LatentState(), club).injuredCount;
      final results = <bool>{
        for (var club = 0; club < 40; club++) roll(club) == 1,
      };
      expect(results, hasLength(2), reason: 'a 50% roll must vary by club');
      for (var club = 0; club < 40; club++) {
        expect(roll(club), roll(club));
      }
    });

    test('a player misses three rounds, then returns', () {
      const clock = InjuryClock();
      var state = const LatentState(injuredCount: 1);
      for (var round = 0; round < 3; round++) {
        state = clock.rest(state);
        expect(state.injuredCount, 1, reason: 'still out after rest $round');
      }
      state = clock.rest(state);
      expect(state.injuredCount, 0);
      expect(state.injuryDays, 0);
    });

    test('two injuries come back one at a time', () {
      const clock = InjuryClock();
      var state = const LatentState(injuredCount: 2);
      final counts = <int>[];
      for (var round = 0; round < 8; round++) {
        state = clock.rest(state);
        counts.add(state.injuredCount);
      }
      expect(counts, <int>[2, 2, 2, 1, 1, 1, 0, 0]);
    });

    test('a fit squad keeps no clock', () {
      const clock = InjuryClock();
      expect(clock.rest(const LatentState()).injuryDays, 0);
    });
  });

  group('SeasonRunner injuries', () {
    test('the injury rate reaches the season', () {
      SeasonResult play(double rate) =>
          SeasonRunner(latentConfig: LatentConfig(injuryBaseRate: rate))
              .run(masterSeed: 11, bettor: const OracleBettor());
      final fit = play(0);
      final crocked = play(0.5);
      expect(
        crocked.matchdays.map((d) => d.profit).toList(),
        isNot(fit.matchdays.map((d) => d.profit).toList()),
      );
    });
  });
}
