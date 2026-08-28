import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const truth = OutcomeProbs(home: 0.43, draw: 0.27, away: 0.30);

  group('Bookmaker', () {
    test('prices every outcome above its true probability', () {
      // That gap IS the book's income; without it there is no house edge.
      final market = const Bookmaker().price(truth);
      for (var i = 0; i < 3; i++) {
        expect(market.impliedProbabilities[i], greaterThan(truth.asList[i]));
      }
    });

    test('reports the margin it actually charged', () {
      final market = const Bookmaker().price(truth);
      expect(market.margin, closeTo(0.05, 1e-12));
    });

    test('fair probabilities recover the book estimate exactly', () {
      // What the player must actually beat: not the quoted price, but the
      // book's own opinion hiding behind it.
      final market = const Bookmaker().price(truth);
      final fair = market.fairProbabilities;
      expect(fair.reduce((a, b) => a + b), closeTo(1, 1e-12));
      for (var i = 0; i < 3; i++) {
        expect(fair[i], closeTo(truth.asList[i], 1e-12));
      }
    });

    test('a shorter price goes on the likelier outcome', () {
      final market = const Bookmaker().price(truth);
      expect(
        market.priceOf(Selection.home).decimal,
        lessThan(market.priceOf(Selection.away).decimal),
      );
    });

    test('selections index the market in a fixed order', () {
      final market = const Bookmaker().price(truth);
      expect(market.priceOf(Selection.home), market.prices[0]);
      expect(market.priceOf(Selection.draw), market.prices[1]);
      expect(market.priceOf(Selection.away), market.prices[2]);
    });

    test('carries a stake limit', () {
      expect(const Bookmaker(openingLimit: 25).price(truth).limit, 25);
      expect(const Bookmaker().price(truth, limit: 400).limit, 400);
    });

    test('a bigger margin means worse prices for the player', () {
      final tight = const Bookmaker(
        marginMethod: ProportionalMargin(0.02),
      ).price(truth);
      final greedy = const Bookmaker(
        marginMethod: ProportionalMargin(0.10),
      ).price(truth);
      expect(
        greedy.priceOf(Selection.home).decimal,
        lessThan(tight.priceOf(Selection.home).decimal),
      );
    });

    test('toString summarises the market', () {
      final market = const Bookmaker().price(truth);
      expect(market.toString(), contains('5.0%'));
    });
  });
}
