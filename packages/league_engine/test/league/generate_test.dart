import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('generateLeague', () {
    test('is deterministic: one seed, one league', () {
      final a = generateLeague(20260828);
      final b = generateLeague(20260828);

      expect(
        a.teams.map((t) => t.name).toList(),
        b.teams.map((t) => t.name).toList(),
      );
      expect(
        a.teams.first.players.map((p) => p.name).toList(),
        b.teams.first.players.map((p) => p.name).toList(),
      );
      expect(a.teams.first.attackStrength, b.teams.first.attackStrength);
    });

    test('different seeds give different leagues', () {
      final a = generateLeague(1);
      final b = generateLeague(2);
      expect(
        a.teams.map((t) => t.name).toList(),
        isNot(b.teams.map((t) => t.name).toList()),
      );
    });

    test('builds the configured shape', () {
      final league = generateLeague(7);
      expect(league.teams, hasLength(20));
      expect(league.fixtures, hasLength(380));
      expect(league.matchdays, 38);
      for (final team in league.teams) {
        expect(team.players, hasLength(18));
      }
    });

    test('honours a custom config', () {
      final league = generateLeague(
        7,
        const LeagueConfig(teamCount: 6, squadSize: 4),
      );
      expect(league.teams, hasLength(6));
      expect(league.fixtures, hasLength(30));
      expect(league.teams.first.players, hasLength(4));
    });

    test('no two clubs share a town', () {
      final towns = generateLeague(99).teams.map((t) => t.town);
      expect(towns.toSet(), hasLength(towns.length));
    });

    test('club ids are stable and dense', () {
      final league = generateLeague(3);
      expect(
        league.teams.map((t) => t.id).toList(),
        List<int>.generate(league.teams.length, (i) => i),
      );
    });

    test('player ids are unique across the whole league', () {
      final league = generateLeague(5);
      final ids = league.teams.expand((t) => t.players).map((p) => p.id);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every club starts unrated, with maximum uncertainty', () {
      // The rating system has seen no results yet and must not pretend it
      // knows anything -- that is what makes early-season odds wide.
      for (final team in generateLeague(11).teams) {
        expect(team.rating.rating, glicko2Center);
        expect(team.rating.deviation, 350);
      }
    });

    test('attributes stay inside their bounds', () {
      for (final team in generateLeague(13).teams) {
        for (final p in team.players) {
          expect(p.attack, inInclusiveRange(1, 99));
          expect(p.defence, inInclusiveRange(1, 99));
          expect(p.stamina, inInclusiveRange(1, 99));
          expect(p.age, inInclusiveRange(18, 35));
        }
      }
    });

    test('clubs actually differ in strength', () {
      // If they did not, there would be nothing to learn and no edge to find.
      final strengths = generateLeague(
        17,
      ).teams.map((t) => t.attackStrength).toList()..sort();
      expect(strengths.last - strengths.first, greaterThan(15));
    });

    test('town names are long enough to read as places', () {
      // Short walks produce truncated stems like "Stre" or "Cind", which read
      // as bugs. Measured at 37.9% of towns before the minimum was raised.
      for (var seed = 0; seed < 20; seed++) {
        for (final team in generateLeague(seed).teams) {
          expect(
            team.town.length,
            greaterThanOrEqualTo(6),
            reason: seed.toString(),
          );
        }
      }
    });
  });
}
