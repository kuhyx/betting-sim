import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

MatchContext _ctx(
  Team home,
  Team away, {
  MatchModifiers homeMods = const MatchModifiers(),
  MatchModifiers awayMods = const MatchModifiers(),
  Weather weather = Weather.clear,
  double refereeBias = 1,
}) {
  return MatchContext(
    home: home,
    away: away,
    homeModifiers: homeMods,
    awayModifiers: awayMods,
    seedPath: const SeedPath(master: 1, season: 0, day: 0, match: 0),
    weather: weather,
    refereeBias: refereeBias,
  );
}

void main() {
  final league = generateLeague(20260828);
  const model = DixonColesModel();

  group('outcomeProbabilities', () {
    test('is pure: it consumes no randomness', () {
      // The bookmaker prices from this. If it drew from the match RNG, quoting
      // odds would perturb the scoreline and replay would break.
      final ctx = _ctx(league.teams[0], league.teams[1]);
      final a = model.outcomeProbabilities(ctx);
      final b = model.outcomeProbabilities(ctx);
      expect(a.home, b.home);
      expect(a.draw, b.draw);
      expect(a.away, b.away);
    });

    test('always sums to exactly 1', () {
      for (final f in league.fixtures.take(60)) {
        final p = model.outcomeProbabilities(
          _ctx(league.teamById(f.homeId), league.teamById(f.awayId)),
        );
        expect(p.home + p.draw + p.away, closeTo(1, 1e-9));
      }
    });

    test('every outcome keeps a positive probability', () {
      final p = model.outcomeProbabilities(
        _ctx(league.teams[0], league.teams[1]),
      );
      for (final v in p.asList) {
        expect(v, greaterThan(0));
      }
    });

    test('home advantage is real and priced', () {
      final team = league.teams[4];
      final other = league.teams[9];
      final atHome = model.outcomeProbabilities(_ctx(team, other)).home;
      final away = model.outcomeProbabilities(_ctx(other, team)).away;
      expect(atHome, greaterThan(away));
    });

    test('a stronger squad is favoured', () {
      final sorted = List<Team>.of(league.teams)
        ..sort((a, b) => a.attackStrength.compareTo(b.attackStrength));
      final weakest = sorted.first;
      final strongest = sorted.last;

      final strongAtHome = model
          .outcomeProbabilities(_ctx(strongest, weakest))
          .home;
      final weakAtHome = model
          .outcomeProbabilities(_ctx(weakest, strongest))
          .home;
      expect(strongAtHome, greaterThan(weakAtHome));
    });

    test('no fixture is a foregone conclusion', () {
      // Measured across a season: home-win probability spans 0.25..0.63. If
      // any match were near-certain there would be no bet worth making.
      for (final f in league.fixtures) {
        final p = model.outcomeProbabilities(
          _ctx(league.teamById(f.homeId), league.teamById(f.awayId)),
        );
        expect(p.home, inExclusiveRange(0.1, 0.85));
      }
    });

    test('bad weather pulls the sides together', () {
      final sorted = List<Team>.of(league.teams)
        ..sort((a, b) => a.attackStrength.compareTo(b.attackStrength));
      const modifiers = LatentModifiers();
      final clear = model.outcomeProbabilities(
        _ctx(sorted.last, sorted.first),
      );
      final storm = model.outcomeProbabilities(
        _ctx(
          sorted.last,
          sorted.first,
          homeMods: modifiers.project(
            const LatentState(),
            weather: Weather.storm,
          ),
          awayMods: modifiers.project(
            const LatentState(),
            weather: Weather.storm,
          ),
          weather: Weather.storm,
        ),
      );
      expect(storm.draw, greaterThan(clear.draw));
    });
  });

  group('simulate', () {
    test('is reproducible from the same seed', () {
      final ctx = _ctx(league.teams[0], league.teams[1]);
      final a = model.simulate(ctx, Mix32Source(7));
      final b = model.simulate(ctx, Mix32Source(7));
      expect(a.homeScore, b.homeScore);
      expect(a.awayScore, b.awayScore);
      expect(a.events.length, b.events.length);
    });

    test('simulated frequencies converge to the stated probabilities', () {
      // The property the whole book depends on: if these disagreed, the odds
      // would be a lie and no amount of skill could beat them.
      final ctx = _ctx(league.teams[0], league.teams[1]);
      final expected = model.outcomeProbabilities(ctx);
      final rng = Mix32Source(999);

      var home = 0;
      var draw = 0;
      const n = 40000;
      for (var i = 0; i < n; i++) {
        final r = model.simulate(ctx, rng);
        if (r.homeWon) {
          home++;
        } else if (r.drawn) {
          draw++;
        }
      }

      // A tight tolerance on purpose. At 0.01 this test still passed while
      // simulate() ignored the Dixon-Coles correction that pricing applied
      // (model 26.12% draws, sampled 24.75%) -- the exact bug that would make
      // the book's odds a lie.
      expect(home / n, closeTo(expected.home, 0.006));
      expect(draw / n, closeTo(expected.draw, 0.006));
    });

    test('emits one goal event per goal', () {
      final ctx = _ctx(league.teams[2], league.teams[3]);
      final rng = Mix32Source(5);
      for (var i = 0; i < 200; i++) {
        final r = model.simulate(ctx, rng);
        final goals = r.events.whereType<GoalEvent>();
        expect(goals, hasLength(r.homeScore + r.awayScore));
        expect(
          goals.where((g) => g.byHome),
          hasLength(r.homeScore),
        );
      }
    });

    test('events are ordered by minute and inside the match', () {
      final ctx = _ctx(league.teams[2], league.teams[3]);
      final rng = Mix32Source(5);
      for (var i = 0; i < 200; i++) {
        final events = model.simulate(ctx, rng).events;
        for (var j = 1; j < events.length; j++) {
          expect(events[j].minute, greaterThanOrEqualTo(events[j - 1].minute));
        }
        for (final e in events) {
          expect(e.minute, inInclusiveRange(1, 90));
        }
      }
    });

    test('a fatigued side scores earlier: fatigue leaves a timing trace', () {
      // Fatigue's fingerprint. It shows up in WHEN goals arrive, not in the
      // final score, so reading it needs match detail rather than the table.
      const modifiers = LatentModifiers();
      final ctx = _ctx(league.teams[0], league.teams[1]);
      final spentCtx = _ctx(
        league.teams[0],
        league.teams[1],
        homeMods: modifiers.project(const LatentState(fatigue: 1)),
      );

      double meanMinute(MatchContext c, int seed) {
        final rng = Mix32Source(seed);
        var total = 0;
        var count = 0;
        for (var i = 0; i < 4000; i++) {
          for (final g
              in model.simulate(c, rng).events.whereType<GoalEvent>()) {
            if (g.byHome) {
              total += g.minute;
              count++;
            }
          }
        }
        return total / count;
      }

      expect(meanMinute(spentCtx, 11), lessThan(meanMinute(ctx, 11)));
    });

    test('a draw of almost exactly 1 still yields a scoreline', () {
      // Inverse-transform sampling walks the grid subtracting cell mass. The
      // largest possible uniform draw must still land on a real scoreline
      // rather than falling off the end of the grid mid-season.
      final ctx = _ctx(league.teams[0], league.teams[1]);
      // The first uniform picks the cell; the rest place goal minutes. The
      // fallback yields maxGoals-maxGoals, so it needs 2*maxGoals of them.
      final rng = ScriptedRandomSource(
        uniforms: <double>[1 - 1e-16, for (var i = 0; i < 24; i++) 0.5],
        normals: [0],
      );
      final result = model.simulate(ctx, rng);
      expect(result.homeScore, greaterThanOrEqualTo(0));
      expect(result.awayScore, greaterThanOrEqualTo(0));
    });

    test('morale widens the spread without moving the mean', () {
      // Morale's fingerprint, and the reason it is modelled as variance only.
      const modifiers = LatentModifiers();
      final fragile = modifiers.project(const LatentState(morale: -1));
      final steady = modifiers.project(const LatentState());

      ({double mean, double variance}) stats(MatchModifiers m, int seed) {
        final rng = Mix32Source(seed);
        final ctx = _ctx(league.teams[0], league.teams[1], homeMods: m);
        var sum = 0.0;
        var sumSq = 0.0;
        const n = 30000;
        for (var i = 0; i < n; i++) {
          final goals = model.simulate(ctx, rng).homeScore.toDouble();
          sum += goals;
          sumSq += goals * goals;
        }
        final mean = sum / n;
        return (mean: mean, variance: sumSq / n - mean * mean);
      }

      final fragileStats = stats(fragile, 3);
      final steadyStats = stats(steady, 3);

      expect(fragileStats.variance, greaterThan(steadyStats.variance));
      expect(fragileStats.mean, closeTo(steadyStats.mean, 0.12));
    });
  });
}
