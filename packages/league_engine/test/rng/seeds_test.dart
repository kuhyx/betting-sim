import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('deriveSeed is a pure function of the path', () {
    test('same path yields the same seed, always', () {
      const path = SeedPath(master: 20260828, season: 3, day: 12, match: 4);
      expect(deriveSeed(path), deriveSeed(path));
    });

    test('frozen literals: the seed contract for a table of paths', () {
      // These pin the generator AND the level-tagging scheme. A change to
      // either invalidates every existing save, so it must be a deliberate,
      // visible edit here rather than silent drift.
      const cases = <SeedPath, String>{
        SeedPath(master: 0): 'ab8f9fde',
        SeedPath(master: 20260828): '98b19cba',
        SeedPath(master: 20260828, season: 1): '3045fad0',
      };
      for (final entry in cases.entries) {
        expect(seedHex(entry.key), entry.value, reason: '${entry.key}');
      }
    });
  });

  group('level tagging prevents collisions', () {
    test('(season 1, day 23) does not collide with (season 12, day 3)', () {
      const a = SeedPath(master: 7, season: 1, day: 23);
      const b = SeedPath(master: 7, season: 12, day: 3);
      expect(deriveSeed(a), isNot(deriveSeed(b)));
    });

    test('depth matters: season 5 differs from day 5', () {
      const asSeason = SeedPath(master: 7, season: 5);
      const asDay = SeedPath(master: 7, day: 5);
      expect(deriveSeed(asSeason), isNot(deriveSeed(asDay)));
    });

    test('no collisions across a wide grid of paths', () {
      final seen = <int, SeedPath>{};
      for (var season = 0; season < 20; season++) {
        for (var day = 0; day < 40; day++) {
          for (var match = 0; match < 10; match++) {
            final path = SeedPath(
              master: 20260828,
              season: season,
              day: day,
              match: match,
            );
            final seed = deriveSeed(path);
            expect(
              seen.containsKey(seed),
              isFalse,
              reason: '$path collides with ${seen[seed]}',
            );
            seen[seed] = path;
          }
        }
      }
      expect(seen, hasLength(20 * 40 * 10));
    });
  });

  group('addressability', () {
    test('a deep path is reachable without walking its ancestors', () {
      // The property the whole design exists for: computing match (9, 30, 5)
      // touches only its own five levels.
      const deep = SeedPath(master: 1, season: 9, day: 30, match: 5);
      final direct = deriveSeed(deep);
      final viaChildren = deriveSeed(
        const SeedPath(master: 1)
            .child(season: 9)
            .child(day: 30)
            .child(match: 5),
      );
      expect(direct, viaChildren);
    });

    test('sibling independence: changing a day leaves other days alone', () {
      const dayA = SeedPath(master: 1, season: 0, day: 5);
      const dayB = SeedPath(master: 1, season: 0, day: 6);
      final before = deriveSeed(dayB);
      // Consuming randomness from day A cannot affect day B, because nothing
      // is shared: each is derived from its own address.
      Mix32Source(deriveSeed(dayA)).uniform01();
      expect(deriveSeed(dayB), before);
    });
  });
}
