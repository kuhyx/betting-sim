import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group("Glickman's published worked example", () {
    // From "Example of the Glicko-2 system" (Glickman, 2013). A player rated
    // 1500/200 with volatility 0.06 and tau 0.5 -- all three are the config
    // defaults, so they are stated here rather than passed -- plays three
    // opponents,
    // winning the first and losing the other two. The paper's stated result
    // is rating 1464.06, RD 151.52, volatility 0.05999.
    //
    // This is the only external check available on the whole rating layer:
    // if these three numbers are right, the algorithm is right.
    const player = Rating(deviation: 200);
    final results = <RatingResult>[
      const RatingResult(
        opponent: Rating(rating: 1400, deviation: 30),
        score: 1,
      ),
      const RatingResult(
        opponent: Rating(rating: 1550, deviation: 100),
        score: 0,
      ),
      const RatingResult(
        opponent: Rating(rating: 1700, deviation: 300),
        score: 0,
      ),
    ];

    test('reproduces the published rating, RD and volatility', () {
      final updated = const Glicko2Updater().update(player, results);

      expect(updated.rating, closeTo(1464.06, 0.01));
      expect(updated.deviation, closeTo(151.52, 0.01));
      expect(updated.volatility, closeTo(0.05999, 0.00001));
    });
  });

  group('Glicko2Updater', () {
    const updater = Glicko2Updater();

    test('a team that did not play grows more uncertain, not more wrong', () {
      const idle = Rating(rating: 1600, deviation: 50);
      final after = updater.update(idle, []);

      expect(after.rating, 1600, reason: 'no results means no new evidence');
      expect(after.deviation, greaterThan(50));
    });

    test(
      'RD is capped so an idle team does not drift past total ignorance',
      () {
        var r = const Rating(deviation: 340);
        for (var period = 0; period < 200; period++) {
          r = updater.update(r, []);
        }
        expect(r.deviation, lessThanOrEqualTo(350.0));
      },
    );

    test('beating a stronger team raises the rating', () {
      const underdog = Rating(rating: 1400, deviation: 100);
      final after = updater.update(underdog, [
        const RatingResult(
          opponent: Rating(rating: 1700, deviation: 50),
          score: 1,
        ),
      ]);
      expect(after.rating, greaterThan(1400));
    });

    test('losing to a weaker team lowers the rating', () {
      const favourite = Rating(rating: 1700, deviation: 100);
      final after = updater.update(favourite, [
        const RatingResult(
          opponent: Rating(rating: 1400, deviation: 50),
          score: 0,
        ),
      ]);
      expect(after.rating, lessThan(1700));
    });

    test('playing reduces uncertainty', () {
      const unknown = Rating(deviation: 300);
      final after = updater.update(unknown, [
        const RatingResult(
          opponent: Rating(deviation: 30),
          score: 1,
        ),
      ]);
      expect(after.deviation, lessThan(300));
    });

    test('a draw against an equal team barely moves the rating', () {
      const even = Rating(deviation: 80);
      final after = updater.update(even, [
        const RatingResult(
          opponent: Rating(deviation: 80),
          score: 0.5,
        ),
      ]);
      expect(after.rating, closeTo(1500, 0.5));
    });
  });
}
