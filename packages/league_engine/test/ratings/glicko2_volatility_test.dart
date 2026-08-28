import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const solver = VolatilitySolver(RatingConfig());

  group('VolatilitySolver on ordinary inputs', () {
    test("matches the published example's step 5", () {
      // Glickman (2013): with phi=1.1513, sigma=0.06, delta=-0.4834,
      // v=1.7785, the new volatility is 0.05999.
      final sigma = solver.solve(
        phi: 1.1513,
        sigma: 0.06,
        delta: -0.4834,
        v: 1.7785,
      );
      expect(sigma, closeTo(0.05999, 0.00001));
    });

    test('a wildly unexpected result raises volatility', () {
      // Large |delta| relative to phi and v: the team is behaving erratically,
      // so the system should become more willing to move its rating.
      final steady = solver.solve(phi: 0.5, sigma: 0.06, delta: 0.1, v: 1.5);
      final erratic = solver.solve(phi: 0.5, sigma: 0.06, delta: 3, v: 1.5);
      expect(erratic, greaterThan(steady));
    });

    test('is deterministic', () {
      final a = solver.solve(phi: 0.8, sigma: 0.05, delta: 0.3, v: 1.2);
      final b = solver.solve(phi: 0.8, sigma: 0.05, delta: 0.3, v: 1.2);
      expect(a, b);
    });
  });

  group('the bracket-expansion branch', () {
    // Taken when delta^2 <= phi^2 + v, i.e. the result was UNsurprising.
    // Ordinary season data lands in the closed-form branch instead, so this
    // is reached here with hand-picked inputs rather than by seed search.
    test('is exercised by a small delta', () {
      final sigma = solver.solve(phi: 0.5, sigma: 0.06, delta: 0.01, v: 2);
      expect(sigma, greaterThan(0));
      expect(sigma, lessThan(0.06), reason: 'a dull result calms volatility');
    });

    test('converges for a range of small deltas', () {
      for (final delta in <double>[0, 0.001, 0.05, 0.2]) {
        final sigma = solver.solve(
          phi: 0.4,
          sigma: 0.06,
          delta: delta,
          v: 1.8,
        );
        expect(sigma, greaterThan(0), reason: 'delta=$delta');
      }
    });

    test('needs no expansion loop: f is provably positive here', () {
      // delta^2 <= phi^2 + v makes term1 <= 0, so f(a - k*tau) > 0 for every
      // k >= 1 and Glickman's "step until f turns negative" loop can never
      // run. If a future edit reintroduces it, this still passes -- but the
      // proof in the source is what keeps the dead branch out.
      for (final v in <double>[0.1, 1, 2, 10]) {
        final sigma = solver.solve(phi: 0.5, sigma: 0.06, delta: 0, v: v);
        expect(sigma, greaterThan(0), reason: 'v=$v');
      }
    });
  });

  group('the iteration cap', () {
    test('fires rather than spinning', () {
      // A convergence tolerance no finite number of iterations can meet.
      const impossible = RatingConfig(convergence: 0, maxIterations: 3);
      expect(
        () =>
            const VolatilitySolver(impossible)
                .solve(phi: 1.1513, sigma: 0.06, delta: -0.4834, v: 1.7785),
        throwsA(isA<StateError>()),
      );
    });

    test('the error names the inputs that caused it', () {
      const impossible = RatingConfig(convergence: 0, maxIterations: 3);
      expect(
        () =>
            const VolatilitySolver(impossible)
                .solve(phi: 1.1513, sigma: 0.06, delta: -0.4834, v: 1.7785),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('did not converge'), contains('phi=')),
          ),
        ),
      );
    });
  });
}
