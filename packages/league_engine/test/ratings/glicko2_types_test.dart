import 'dart:math' as math;

import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Rating', () {
    test('defaults describe a brand-new, totally unknown team', () {
      const r = Rating();
      expect(r.rating, glicko2Center);
      expect(r.deviation, 350);
      expect(r.volatility, 0.06);
    });

    test('converts to the internal scale', () {
      const r = Rating(deviation: glicko2Scale);
      expect(r.internal.mu, closeTo(0, 1e-12));
      expect(r.internal.phi, closeTo(1, 1e-12));
    });

    test('a rating above centre has positive mu', () {
      const r = Rating(rating: glicko2Center + glicko2Scale);
      expect(r.internal.mu, closeTo(1, 1e-12));
    });

    test('the interval widens with uncertainty', () {
      const sure = Rating(deviation: 25);
      const unsure = Rating(deviation: 200);
      expect(sure.interval.low, 1450);
      expect(sure.interval.high, 1550);
      final sureWidth = sure.interval.high - sure.interval.low;
      final unsureWidth = unsure.interval.high - unsure.interval.low;
      expect(unsureWidth, greaterThan(sureWidth));
    });

    test('copyWith replaces only what it is given', () {
      const base = Rating(rating: 1600, deviation: 80, volatility: 0.05);
      expect(base.copyWith(rating: 1700).rating, 1700);
      expect(base.copyWith(rating: 1700).deviation, 80);
      expect(base.copyWith(deviation: 40).deviation, 40);
      expect(base.copyWith(volatility: 0.09).volatility, 0.09);
      expect(base.copyWith().rating, 1600);
    });

    test('toString shows the estimate and its uncertainty', () {
      expect(
        const Rating(rating: 1523.44, deviation: 88.1).toString(),
        'Rating(1523.4 ±88.1)',
      );
    });
  });

  group('glickoG', () {
    test('is 1 when the opponent is perfectly known', () {
      expect(glickoG(0), 1);
    });

    test('shrinks as the opponent gets less known', () {
      expect(glickoG(2), lessThan(glickoG(1)));
      expect(glickoG(1), lessThan(glickoG(0)));
    });
  });

  group('glickoE', () {
    test('is 0.5 between identical, perfectly known teams', () {
      expect(glickoE(0, 0, 0), closeTo(0.5, 1e-12));
    });

    test('favours the stronger team', () {
      expect(glickoE(1, 0, 0), greaterThan(0.5));
      expect(glickoE(0, 1, 0), lessThan(0.5));
    });

    test('is symmetric about the midpoint', () {
      expect(glickoE(1, 0, 0) + glickoE(0, 1, 0), closeTo(1, 1e-12));
    });

    test('an uncertain opponent pulls the expectation toward 0.5', () {
      final known = glickoE(1, 0, 0);
      final unknown = glickoE(1, 0, 3);
      expect((unknown - 0.5).abs(), lessThan((known - 0.5).abs()));
    });

    test('matches the logistic form it is defined by', () {
      const mu = 0.5;
      const oppMu = -0.2;
      const oppPhi = 0.8;
      final expected = 1.0 / (1.0 + math.exp(-glickoG(oppPhi) * (mu - oppMu)));
      expect(glickoE(mu, oppMu, oppPhi), closeTo(expected, 1e-12));
    });
  });

  group('RatingConfig', () {
    test('defaults follow Glickman recommendations', () {
      const c = RatingConfig();
      expect(c.tau, 0.5);
      expect(c.maxIterations, 100);
      expect(c.maxDeviation, 350);
      expect(c.convergence, lessThan(0.001));
    });
  });
}
