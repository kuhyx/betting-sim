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
}
