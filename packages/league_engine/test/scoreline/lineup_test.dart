import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

Player _player(int id, {double attack = 50, double defence = 50}) => Player(
  id: id,
  name: 'p$id',
  attack: attack,
  defence: defence,
  stamina: 60,
  age: 25,
);

Team _team(List<Player> players) => Team(
  id: 1,
  name: 'Test',
  town: 'Testerly',
  players: players,
  rating: const Rating(),
);

void main() {
  group('pickLineup', () {
    final squad = <Player>[
      for (var i = 0; i < 18; i++) _player(i, attack: 40.0 + i),
    ];

    test('starts the strongest eleven when nobody is missing', () {
      final sheet = pickLineup(_team(squad), missingCount: 0);

      expect(sheet.starting, hasLength(11));
      expect(sheet.missing, isEmpty);
      expect(sheet.starting.first.id, 17, reason: 'strongest first');
      expect(sheet.starting.last.id, 7);
    });

    test('leaves the best players out when they are injured', () {
      // Injuries cost a club its best, which is what makes team news worth
      // reading rather than a cosmetic list of names.
      final sheet = pickLineup(_team(squad), missingCount: 3);

      expect(sheet.missing.map((p) => p.id), <int>[17, 16, 15]);
      expect(sheet.starting.first.id, 14);
      expect(sheet.starting, hasLength(11));
    });

    test('breaks ties by id, so the VM and JavaScript agree', () {
      // List.sort is not documented as stable; without the tie-break these
      // could order differently on the two platforms the app ships to.
      final level = <Player>[for (var i = 0; i < 5; i++) _player(4 - i)];
      final sheet = pickLineup(_team(level), missingCount: 0);

      expect(sheet.starting.map((p) => p.id), <int>[0, 1, 2, 3, 4]);
    });

    test('fields whoever is left when more are missing than exist', () {
      final sheet = pickLineup(_team(squad), missingCount: 40);

      expect(sheet.missing, hasLength(18));
      expect(sheet.starting, isEmpty);
    });

    test('handles a club with no squad at all', () {
      final sheet = pickLineup(_team(<Player>[]), missingCount: 0);

      expect(sheet.starting, isEmpty);
      expect(sheet.missing, isEmpty);
    });

    test('honours a different lineup size', () {
      final sheet = pickLineup(
        _team(squad),
        missingCount: 0,
        config: const NarrationConfig(lineupSize: 5),
      );

      expect(sheet.starting, hasLength(5));
    });
  });

  group('pickWeighted', () {
    final pool = <Player>[
      _player(0, attack: 10),
      _player(1, attack: 20),
      _player(2, attack: 70),
    ];

    test('returns null rather than throwing on an empty pool', () {
      // A club whose whole squad is unavailable is a legal state, and
      // GoalEvent.playerId has always been nullable for exactly this.
      final rng = ScriptedRandomSource(uniforms: <double>[0.5]);
      expect(pickWeighted(<Player>[], (p) => p.attack, rng), isNull);
    });

    test('lands in the bucket the draw points at', () {
      // Weights 10/20/70 out of 100.
      Player? pick(double u) => pickWeighted(
        pool,
        (p) => p.attack,
        ScriptedRandomSource(uniforms: <double>[u]),
      );

      expect(pick(0.05)!.id, 0);
      expect(pick(0.20)!.id, 1);
      expect(pick(0.90)!.id, 2, reason: 'the loop falls through to the last');
    });

    test('never leaves the walk with nobody to return', () {
      // The top of the range is the fall-through, so rounding drift cannot
      // run the walk off the end.
      final rng = ScriptedRandomSource(uniforms: <double>[0.999999]);
      expect(pickWeighted(pool, (p) => p.attack, rng)!.id, 2);
    });

    test('picks the first when every weight is zero', () {
      final rng = ScriptedRandomSource(uniforms: <double>[0.5]);
      expect(pickWeighted(pool, (_) => 0, rng)!.id, 0);
    });
  });
}
