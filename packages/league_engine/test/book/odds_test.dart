import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Odds', () {
    test('an even-money price is 2.00', () {
      const evens = Odds(2);
      expect(evens.profit, 1);
      expect(evens.impliedProbability, 0.5);
    });

    test('converts to and from a probability', () {
      final o = Odds.fromProbability(0.25);
      expect(o.decimal, 4);
      expect(o.impliedProbability, closeTo(0.25, 1e-12));
    });

    test('rejects an impossible probability', () {
      expect(() => Odds.fromProbability(0), throwsArgumentError);
      expect(() => Odds.fromProbability(1), throwsArgumentError);
      expect(() => Odds.fromProbability(-0.1), throwsArgumentError);
      expect(() => Odds.fromProbability(1.5), throwsArgumentError);
    });

    group('American notation', () {
      test('-110 is the standard US price on a near coin flip', () {
        // 1.909... decimal, 52.38% implied: the canonical example.
        final o = Odds.fromProbability(0.5238);
        expect(o.american, closeTo(-110, 1));
        expect(o.format(OddsFormat.american), '-110');
      });

      test('an underdog is quoted positive', () {
        expect(const Odds(2.4).american, closeTo(140, 0.01));
        expect(const Odds(2.4).format(OddsFormat.american), '+140');
      });

      test('exactly evens sits on the boundary', () {
        expect(const Odds(2).american, 100);
      });
    });

    group('fractional notation', () {
      test('renders the familiar shapes', () {
        expect(const Odds(3).format(OddsFormat.fractional), '2/1');
        expect(const Odds(3.5).format(OddsFormat.fractional), '5/2');
        expect(const Odds(1.5).format(OddsFormat.fractional), '1/2');
      });

      test('reduces to the closest sensible denominator', () {
        final f = const Odds(1.91).fractional;
        expect(f.numerator / f.denominator, closeTo(0.91, 0.02));
      });
    });

    test('decimal notation shows two places', () {
      expect(const Odds(1.9090909).format(OddsFormat.decimal), '1.91');
      expect(const Odds(2.5).toString(), '2.50');
    });

    test('the overround of a 1.91/1.91 two-way market is 4.7%', () {
      // The worked example every betting primer opens with.
      const price = Odds(1.91);
      final total = price.impliedProbability * 2;
      expect(total, closeTo(1.0471, 0.0001));
    });
  });
}
