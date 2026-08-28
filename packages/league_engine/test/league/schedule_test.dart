import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('buildSchedule', () {
    test('needs at least two clubs', () {
      expect(buildSchedule([]), isEmpty);
      expect(buildSchedule([1]), isEmpty);
    });

    for (final n in <int>[2, 4, 5, 8, 20]) {
      group('with $n clubs', () {
        final ids = List<int>.generate(n, (i) => i);
        final fixtures = buildSchedule(ids);

        test('plays every ordered pair exactly once', () {
          expect(fixtures, hasLength(n * (n - 1)));
          final pairs = fixtures.map((f) => '${f.homeId}>${f.awayId}');
          expect(pairs.toSet(), hasLength(fixtures.length));
        });

        test('no club appears twice on one matchday', () {
          final days = fixtures.map((f) => f.day).toSet();
          for (final day in days) {
            final seen = <int>{};
            for (final f in fixtures.where((f) => f.day == day)) {
              expect(seen.add(f.homeId), isTrue, reason: 'day $day');
              expect(seen.add(f.awayId), isTrue, reason: 'day $day');
            }
          }
        });

        test('every club has an equal share of home matches', () {
          for (final id in ids) {
            final home = fixtures.where((f) => f.homeId == id).length;
            final away = fixtures.where((f) => f.awayId == id).length;
            expect(home, away, reason: 'club $id');
            expect(home, n - 1);
          }
        });

        test('runs for the expected number of matchdays', () {
          final odd = n.isOdd;
          // An odd league inserts a bye, so it needs n rounds per half,
          // not n-1.
          final perHalf = odd ? n : n - 1;
          expect(fixtures.map((f) => f.day).toSet(), hasLength(perHalf * 2));
        });
      });
    }

    test('the second half mirrors the first with venues swapped', () {
      final fixtures = buildSchedule([0, 1, 2, 3]);
      final half = fixtures.map((f) => f.day).toSet().length ~/ 2;
      final first = fixtures.where((f) => f.day < half);
      for (final f in first) {
        expect(
          fixtures.any((g) => g.homeId == f.awayId && g.awayId == f.homeId),
          isTrue,
          reason: 'no return fixture for $f',
        );
      }
    });

    test('an odd league gives every club exactly one bye per half', () {
      final fixtures = buildSchedule([0, 1, 2, 3, 4]);
      final days = fixtures.map((f) => f.day).toSet().toList()..sort();
      for (final id in <int>[0, 1, 2, 3, 4]) {
        final playing = days
            .where(
              (d) => fixtures.any(
                (f) => f.day == d && (f.homeId == id || f.awayId == id),
              ),
            )
            .length;
        expect(playing, days.length - 2, reason: 'club $id');
      }
    });
  });
}
