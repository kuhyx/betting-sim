import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

Player _player(int id, {double attack = 50, double defence = 50}) => Player(
  id: id,
  name: 'P$id',
  attack: attack,
  defence: defence,
  stamina: 70,
  age: 25,
);

void main() {
  group('Team', () {
    test('averages its squad', () {
      final team = Team(
        id: 0,
        name: 'Test United',
        town: 'Test',
        players: [
          _player(0, attack: 40, defence: 60),
          _player(1, attack: 60, defence: 40),
        ],
        rating: const Rating(),
      );
      expect(team.attackStrength, 50);
      expect(team.defenceStrength, 50);
    });

    test('an empty squad has zero strength rather than dividing by zero', () {
      const team = Team(
        id: 0,
        name: 'Empty',
        town: 'Nowhere',
        players: [],
        rating: Rating(),
      );
      expect(team.attackStrength, 0);
      expect(team.defenceStrength, 0);
    });

    test('copyWith replaces only what it is given', () {
      final team = Team(
        id: 3,
        name: 'Keep',
        town: 'Same',
        players: [_player(0)],
        rating: const Rating(),
      );
      final rerated = team.copyWith(rating: const Rating(rating: 1700));
      expect(rerated.rating.rating, 1700);
      expect(rerated.name, 'Keep');
      expect(rerated.id, 3);
      expect(team.copyWith(players: []).players, isEmpty);
      expect(team.copyWith().name, 'Keep');
    });

    test('toString names the club', () {
      expect(
        Team(
          id: 0,
          name: 'Ravenshambe United',
          town: 'Ravenshambe',
          players: const [],
          rating: const Rating(),
        ).toString(),
        'Team(Ravenshambe United)',
      );
    });
  });

  group('Player', () {
    test('toString names the player', () {
      expect(_player(1).toString(), 'Player(P1)');
    });
  });

  group('Fixture', () {
    test('toString shows day and sides', () {
      expect(
        const Fixture(day: 4, homeId: 1, awayId: 2).toString(),
        'Fixture(d4: 1 v 2)',
      );
    });
  });

  group('League', () {
    final league = generateLeague(1, const LeagueConfig(teamCount: 4));

    test('reports its matchday count', () {
      expect(league.matchdays, 6);
    });

    test('an empty league has no matchdays', () {
      const empty = League(teams: [], fixtures: []);
      expect(empty.matchdays, 0);
    });

    test('finds the fixtures for a day', () {
      final day = league.fixturesOn(0);
      expect(day, hasLength(2));
      expect(day.every((f) => f.day == 0), isTrue);
    });

    test('looks a club up by id', () {
      expect(league.teamById(2).id, 2);
    });
  });
}
