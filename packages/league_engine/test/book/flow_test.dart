import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const truth = OutcomeProbs(home: 0.55, draw: 0.25, away: 0.20);

  group('OpeningLine', () {
    test('the book is good but not omniscient', () {
      // The gap between the book's estimate and the truth is the player's
      // entire opportunity. With zero noise there would be nothing to beat.
      const opening = OpeningLine();
      final rng = Mix32Source(3);
      var anyDifferent = false;
      for (var i = 0; i < 50; i++) {
        final est = opening.estimate(truth, 200, rng);
        if ((est.home - truth.home).abs() > 1e-9) {
          anyDifferent = true;
        }
      }
      expect(anyDifferent, isTrue);
    });

    test('its estimate is still a valid distribution', () {
      const opening = OpeningLine();
      final rng = Mix32Source(5);
      for (var i = 0; i < 200; i++) {
        final est = opening.estimate(truth, 400, rng);
        expect(est.home + est.draw + est.away, closeTo(1, 1e-9));
        for (final p in est.asList) {
          expect(p, greaterThan(0));
        }
      }
    });

    test('it is unbiased: the error washes out over many matches', () {
      const opening = OpeningLine();
      final rng = Mix32Source(11);
      var total = 0.0;
      const n = 20000;
      for (var i = 0; i < n; i++) {
        total += opening.estimate(truth, 200, rng).home;
      }
      expect(total / n, closeTo(truth.home, 0.01));
    });

    test('an unknown club makes for a softer market', () {
      // Ties book confidence to the SAME rating deviation that drives scouting
      // fog, so "nobody knows this club" widens the market and blurs the
      // player's information at once. Early season is where the value is.
      const opening = OpeningLine();

      double spread(double deviation, int seed) {
        final rng = Mix32Source(seed);
        var sumSq = 0.0;
        const n = 4000;
        for (var i = 0; i < n; i++) {
          final err = opening.estimate(truth, deviation, rng).home - truth.home;
          sumSq += err * err;
        }
        return sumSq / n;
      }

      expect(spread(700, 7), greaterThan(spread(100, 7)));
    });

    test('zero noise reproduces the truth exactly', () {
      const perfect = OpeningLine(baseNoise: 0, uncertaintyWeight: 0);
      final est = perfect.estimate(truth, 500, Mix32Source(1));
      expect(est.home, closeTo(truth.home, 1e-12));
    });
  });

  group('MoneyFlow', () {
    test('sharp money walks the line toward the truth', () {
      const flow = MoneyFlow(publicWeight: 0);
      final rng = Mix32Source(2);
      var current = const OutcomeProbs(home: 0.40, draw: 0.30, away: 0.30);

      final before = (current.home - truth.home).abs();
      for (var i = 0; i < 5; i++) {
        current = flow.step(current, truth, Selection.home, rng);
      }
      expect((current.home - truth.home).abs(), lessThan(before));
    });

    test('public money drags the line off the truth', () {
      // This is what creates value on the unfashionable side.
      const sharpOnly = MoneyFlow(publicWeight: 0);
      const withPublic = MoneyFlow(publicWeight: 1, publicBiasStrength: 0.2);
      const start = OutcomeProbs(home: 0.5, draw: 0.27, away: 0.23);

      final sharp = sharpOnly.step(
        start,
        truth,
        Selection.home,
        ScriptedRandomSource(uniforms: [1]),
      );
      final public = withPublic.step(
        start,
        truth,
        Selection.home,
        ScriptedRandomSource(uniforms: [1]),
      );

      expect(public.home, greaterThan(sharp.home));
    });

    test('the line stays a valid distribution as it moves', () {
      const flow = MoneyFlow();
      final rng = Mix32Source(4);
      var current = const OutcomeProbs(home: 0.33, draw: 0.34, away: 0.33);
      for (var i = 0; i < 40; i++) {
        current = flow.step(current, truth, Selection.away, rng);
        expect(current.home + current.draw + current.away, closeTo(1, 1e-9));
      }
    });

    test('an already-correct line barely moves', () {
      const flow = MoneyFlow(publicWeight: 0);
      final moved = flow.step(truth, truth, Selection.home, Mix32Source(1));
      expect(moved.home, closeTo(truth.home, 1e-9));
    });
  });
}
