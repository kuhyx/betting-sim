import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Mix32Source', () {
    test('is reproducible from a seed', () {
      final a = Mix32Source(42);
      final b = Mix32Source(42);
      final drawsA = List.generate(20, (_) => a.uniform01());
      final drawsB = List.generate(20, (_) => b.uniform01());
      expect(drawsA, drawsB);
    });

    test('different seeds diverge', () {
      expect(
        Mix32Source(1).uniform01(),
        isNot(Mix32Source(2).uniform01()),
      );
    });

    test('uniform01 stays in [0, 1)', () {
      final rng = Mix32Source(7);
      for (var i = 0; i < 10000; i++) {
        final v = rng.uniform01();
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('uniform01 has roughly the right mean', () {
      final rng = Mix32Source(11);
      var total = 0.0;
      const n = 200000;
      for (var i = 0; i < n; i++) {
        total += rng.uniform01();
      }
      expect(total / n, closeTo(0.5, 0.01));
    });

    test('state advances and is observable', () {
      final rng = Mix32Source(3)..uniform01();
      expect(rng.state, isNot(3));
    });

    group('randint', () {
      test('covers its whole inclusive range', () {
        final rng = Mix32Source(5);
        final seen = <int>{};
        for (var i = 0; i < 5000; i++) {
          seen.add(rng.randint(1, 6));
        }
        expect(seen, <int>{1, 2, 3, 4, 5, 6});
      });

      test('a degenerate range returns its only value', () {
        expect(Mix32Source(1).randint(4, 4), 4);
      });

      test('rejects an inverted range', () {
        expect(() => Mix32Source(1).randint(5, 4), throwsArgumentError);
      });
    });

    group('normal', () {
      test('has roughly the requested mean and spread', () {
        final rng = Mix32Source(13);
        const n = 200000;
        var sum = 0.0;
        var sumSq = 0.0;
        for (var i = 0; i < n; i++) {
          final v = rng.normal(10, 2);
          sum += v;
          sumSq += v * v;
        }
        final mean = sum / n;
        expect(mean, closeTo(10, 0.05));
        expect((sumSq / n) - mean * mean, closeTo(4, 0.1));
      });
    });

    group('poisson', () {
      test('has roughly the requested rate', () {
        final rng = Mix32Source(17);
        const n = 100000;
        var total = 0;
        for (var i = 0; i < n; i++) {
          total += rng.poisson(1.5);
        }
        expect(total / n, closeTo(1.5, 0.03));
      });

      test('lambda of zero always yields zero', () {
        final rng = Mix32Source(1);
        for (var i = 0; i < 100; i++) {
          expect(rng.poisson(0), 0);
        }
      });

      test('rejects a negative lambda', () {
        expect(() => Mix32Source(1).poisson(-1), throwsArgumentError);
      });
    });
  });
}
