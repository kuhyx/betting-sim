import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ProportionalMargin', () {
    test('inflates the market to exactly 1 + v', () {
      const probs = <double>[0.5, 0.3, 0.2];
      for (final v in <double>[0, 0.02, 0.05, 0.12]) {
        final priced = ProportionalMargin(v).apply(probs);
        expect(priced.reduce((a, b) => a + b), closeTo(1 + v, 1e-12));
      }
    });

    test('THE gate-3 identity: a random bettor loses exactly v/(1+v)', () {
      // With price_i = 1/(p_i(1+v)), the expected return on ANY selection is
      // p_i * price_i = 1/(1+v), independent of the probabilities and of which
      // outcome is picked. This turns "a random bettor loses roughly the
      // overround" from a Monte-Carlo vibe check into an exact assertion.
      for (final v in <double>[0.02, 0.05, 0.1]) {
        final margin = ProportionalMargin(v);
        for (final probs in <List<double>>[
          [0.5, 0.3, 0.2],
          [0.43, 0.27, 0.30],
          [0.25, 0.25, 0.5],
        ]) {
          final priced = margin.apply(probs);
          for (var i = 0; i < 3; i++) {
            final odds = Odds.fromProbability(priced[i]);
            final expectedReturn = probs[i] * odds.decimal;
            expect(expectedReturn, closeTo(1 / (1 + v), 1e-12));
            expect(expectedReturn - 1, closeTo(-v / (1 + v), 1e-12));
          }
        }
      }
    });

    test('preserves the ordering of the outcomes', () {
      final priced = const ProportionalMargin(0.05).apply([0.5, 0.3, 0.2]);
      expect(priced[0], greaterThan(priced[1]));
      expect(priced[1], greaterThan(priced[2]));
    });

    test('a zero margin leaves the probabilities untouched', () {
      const probs = <double>[0.5, 0.3, 0.2];
      expect(const ProportionalMargin(0).apply(probs), probs);
    });

    test(
      'caps a near-certain outcome rather than pricing an impossibility',
      () {
        // A true probability above 1/(1+v) would price above 1, which has no
        // valid decimal odds. Unreachable for real fixtures -- the most
        // one-sided match in this league sits at 0.63 against a 0.952 threshold
        // -- but the market must degrade instead of throwing.
        final priced = const ProportionalMargin(0.05)
            .apply([0.99, 0.005, 0.005]);
        expect(priced[0], lessThan(1));
        expect(() => Odds.fromProbability(priced[0]), returnsNormally);
      },
    );
  });

  group('AdditiveMargin', () {
    test('adds the margin evenly and still totals 1 + v', () {
      final priced = const AdditiveMargin(0.06).apply([0.5, 0.3, 0.2]);
      expect(priced.reduce((a, b) => a + b), closeTo(1.06, 1e-12));
    });

    test('leans on longshots and spares favourites', () {
      // The whole reason a second method exists: it moves the edge to a
      // different part of the market. An even split is a LARGER relative
      // mark-up on a small probability, which reproduces the real-world
      // favourite-longshot bias:
      //   p=0.70  proportional x1.060   additive x1.029
      //   p=0.10  proportional x1.060   additive x1.200
      const probs = <double>[0.7, 0.2, 0.1];
      final proportional = const ProportionalMargin(0.06).apply(probs);
      final additive = const AdditiveMargin(0.06).apply(probs);

      expect(
        additive[2] / probs[2],
        greaterThan(proportional[2] / probs[2]),
        reason: 'the longshot is marked up harder',
      );
      expect(
        additive[0] / probs[0],
        lessThan(proportional[0] / probs[0]),
        reason: 'the favourite is priced more generously',
      );
    });

    test('caps a near-certain outcome', () {
      final priced = const AdditiveMargin(0.05).apply([0.995, 0.003, 0.002]);
      expect(priced[0], lessThan(1));
    });
  });

  group('removeVig', () {
    test('recovers the true probabilities from a proportional market', () {
      // Exact for a proportional margin, which is why the no-vig calculator
      // the player is given is honest rather than approximate.
      const truth = <double>[0.43, 0.27, 0.30];
      final priced = const ProportionalMargin(0.05).apply(truth);
      final recovered = removeVig(priced);
      for (var i = 0; i < 3; i++) {
        expect(recovered[i], closeTo(truth[i], 1e-12));
      }
    });

    test('always returns a distribution summing to 1', () {
      final stripped = removeVig([0.55, 0.32, 0.25]);
      expect(stripped.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });
  });
}
