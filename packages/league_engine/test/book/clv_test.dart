import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const clv = ClvCalculator();
  const book = Bookmaker();

  Market marketFor(double home, double draw, double away) =>
      book.price(OutcomeProbs(home: home, draw: draw, away: away));

  group('ClvCalculator', () {
    test('taking a better price than the close is positive CLV', () {
      // The player backed home at 2.50 and the market closed shorter, meaning
      // the market came to agree with them.
      final closing = marketFor(0.5, 0.27, 0.23);
      final value = clv.forBet(
        selection: Selection.home,
        taken: const Odds(2.5),
        closing: closing,
      );
      expect(value, greaterThan(0));
    });

    test('taking a worse price than the close is negative CLV', () {
      final closing = marketFor(0.5, 0.27, 0.23);
      final value = clv.forBet(
        selection: Selection.home,
        taken: const Odds(1.6),
        closing: closing,
      );
      expect(value, lessThan(0));
    });

    test('taking exactly the closing price is zero CLV', () {
      // The boundary case, and the one a naive implementation gets wrong by
      // forgetting to strip the margin from both sides.
      final closing = marketFor(0.43, 0.27, 0.30);
      final value = clv.forBet(
        selection: Selection.home,
        taken: closing.priceOf(Selection.home),
        closing: closing,
      );
      expect(value, closeTo(0, 1e-12));
    });

    test('measures skill, not the book margin', () {
      // Comparing raw quoted odds would score the book's own margin as though
      // it were the player's edge. Both sides are de-vigged first, so betting
      // into an identical market scores exactly zero however fat the margin.
      for (final v in <double>[0.02, 0.08, 0.15]) {
        final wide = Bookmaker(marginMethod: ProportionalMargin(v))
            .price(const OutcomeProbs(home: 0.43, draw: 0.27, away: 0.30));
        expect(
          clv.forBet(
            selection: Selection.draw,
            taken: wide.priceOf(Selection.draw),
            closing: wide,
          ),
          closeTo(0, 1e-12),
          reason: 'margin $v',
        );
      }
    });

    test('averages across many bets', () {
      expect(clv.average([0.01, 0.03, -0.02]), closeTo(0.006667, 1e-6));
      expect(clv.average([]), 0);
    });

    test('beat rate near 0.5 is what luck alone produces', () {
      expect(clv.beatRate([0.01, -0.01, 0.02, -0.02]), 0.5);
      expect(clv.beatRate([0.01, 0.02, 0.03, 0.04]), 1.0);
      expect(clv.beatRate([]), 0);
    });

    test('a bet exactly on the line does not count as beating it', () {
      expect(clv.beatRate([0, 0, 0]), 0);
    });
  });
}
