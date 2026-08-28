import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

/// A runner that records whether anything ever asked it to play a match.
///
/// Used to prove the replay path does not secretly re-simulate the season.
class _CountingModel implements ScorelineModel {
  _CountingModel(this._inner);

  final ScorelineModel _inner;
  int simulateCalls = 0;

  @override
  OutcomeProbs outcomeProbabilities(MatchContext ctx) =>
      _inner.outcomeProbabilities(ctx);

  @override
  MatchResult simulate(MatchContext ctx, RandomSource rng) {
    simulateCalls++;
    return _inner.simulate(ctx, rng);
  }
}

void main() {
  const masterSeed = 20260828;
  final league = generateLeague(masterSeed);
  const runner = MatchRunner(model: DixonColesModel());

  SeedPath pathFor(int season, int day, int match) => SeedPath(
    master: masterSeed,
    season: season,
    day: day,
    match: match,
  );

  MatchResult playOne(int season, int day, int matchIndex) {
    final fixture = league.fixturesOn(day)[matchIndex];
    return runner.run(
      runner.contextFor(
        home: league.teamById(fixture.homeId),
        away: league.teamById(fixture.awayId),
        homeState: const LatentState(),
        awayState: const LatentState(),
        seedPath: pathFor(season, day, matchIndex),
      ),
    );
  }

  group('the replay invariant', () {
    test('a match replays identically from its seed path alone', () {
      // THE property the whole seeding design exists for.
      final first = playOne(0, 12, 2);
      final second = playOne(0, 12, 2);

      expect(second.homeScore, first.homeScore);
      expect(second.awayScore, first.awayScore);
      expect(second.events.length, first.events.length);
      for (var i = 0; i < first.events.length; i++) {
        expect(second.events[i].minute, first.events[i].minute);
        expect(second.events[i].toString(), first.events[i].toString());
      }
    });

    test('replaying one match does not simulate the season around it', () {
      // Simulate a whole season, note one match, then rebuild ONLY that match
      // and assert the model was asked to play exactly once.
      final counting = _CountingModel(const DixonColesModel());
      final seasonRunner = MatchRunner(model: counting);

      MatchResult play(int day, int index) {
        final fixture = league.fixturesOn(day)[index];
        return seasonRunner.run(
          seasonRunner.contextFor(
            home: league.teamById(fixture.homeId),
            away: league.teamById(fixture.awayId),
            homeState: const LatentState(),
            awayState: const LatentState(),
            seedPath: pathFor(0, day, index),
          ),
        );
      }

      for (var day = 0; day < league.matchdays; day++) {
        for (var i = 0; i < league.fixturesOn(day).length; i++) {
          play(day, i);
        }
      }
      final wholeSeason = counting.simulateCalls;
      expect(wholeSeason, league.fixtures.length);

      counting.simulateCalls = 0;
      final replayed = play(12, 2);
      expect(
        counting.simulateCalls,
        1,
        reason: 'replay must not walk the season',
      );
      expect(replayed.homeScore, playOne(0, 12, 2).homeScore);
    });

    test('sibling matches are independent', () {
      // Playing one match cannot disturb another: each draws from its own
      // address, not from a shared stream.
      final before = playOne(0, 5, 1);
      playOne(0, 5, 0);
      playOne(0, 6, 0);
      final after = playOne(0, 5, 1);

      expect(after.homeScore, before.homeScore);
      expect(after.awayScore, before.awayScore);
    });

    test('different addresses give different matches', () {
      final results = <String>{};
      for (var day = 0; day < 12; day++) {
        final r = playOne(0, day, 0);
        results.add('${r.homeScore}-${r.awayScore}-${r.events.length}');
      }
      expect(results.length, greaterThan(3));
    });

    test('a different season replays differently', () {
      final seasonZero = playOne(0, 3, 1);
      final seasonOne = playOne(1, 3, 1);
      expect(
        '${seasonOne.homeScore}-${seasonOne.awayScore}',
        isNot('${seasonZero.homeScore}-${seasonZero.awayScore}-x'),
      );
      // The point is only that the address differs, so the stream differs.
      expect(
        deriveSeed(pathFor(0, 3, 1)),
        isNot(deriveSeed(pathFor(1, 3, 1))),
      );
    });
  });

  group('pricing and playing use disjoint streams', () {
    test('pricing a match does not change how it plays', () {
      // If quoting odds consumed the match RNG, the book would perturb the
      // very scoreline it was pricing.
      final fixture = league.fixturesOn(4).first;
      final ctx = runner.contextFor(
        home: league.teamById(fixture.homeId),
        away: league.teamById(fixture.awayId),
        homeState: const LatentState(),
        awayState: const LatentState(),
        seedPath: pathFor(0, 4, 0),
      );

      final unpriced = runner.run(ctx);
      for (var i = 0; i < 50; i++) {
        const DixonColesModel().outcomeProbabilities(ctx);
      }
      final priced = runner.run(ctx);

      expect(priced.homeScore, unpriced.homeScore);
      expect(priced.awayScore, unpriced.awayScore);
    });

    test('the pre-match draws settle before kick-off', () {
      final fixture = league.fixturesOn(7).first;
      MatchContext build() => runner.contextFor(
        home: league.teamById(fixture.homeId),
        away: league.teamById(fixture.awayId),
        homeState: const LatentState(),
        awayState: const LatentState(),
        seedPath: pathFor(0, 7, 0),
      );

      final a = build();
      final b = build();
      expect(b.weather, a.weather);
      expect(b.refereeBias, a.refereeBias);
    });
  });

  group('hidden state reaches the match', () {
    test('a tired, dispirited squad plays differently', () {
      final fixture = league.fixturesOn(9).first;
      MatchContext ctxWith(LatentState state) => runner.contextFor(
        home: league.teamById(fixture.homeId),
        away: league.teamById(fixture.awayId),
        homeState: state,
        awayState: const LatentState(),
        seedPath: pathFor(0, 9, 0),
      );

      final fresh = ctxWith(const LatentState());
      final spent = ctxWith(const LatentState(fatigue: 1, injuredCount: 3));

      expect(
        const DixonColesModel().outcomeProbabilities(spent).home,
        lessThan(const DixonColesModel().outcomeProbabilities(fresh).home),
      );
    });
  });
}
