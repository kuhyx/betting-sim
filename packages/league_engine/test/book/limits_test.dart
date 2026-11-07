import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const policy = LimitPolicy();

  group('a market takes more as it sharpens', () {
    test('an opening line is a guess, so the book risks little on it', () {
      expect(policy.limitAt(0), policy.openingLimit);
      expect(policy.limitAt(1), policy.closingLimit);
    });

    test('the limit rises monotonically toward kick-off', () {
      var previous = policy.limitAt(0);
      for (var t = 0.1; t <= 1.0; t += 0.1) {
        final current = policy.limitAt(t);
        expect(current, greaterThan(previous));
        previous = current;
      }
    });

    test('sharpness outside 0..1 is clamped', () {
      expect(policy.limitAt(-5), policy.openingLimit);
      expect(policy.limitAt(5), policy.closingLimit);
    });
  });

  group('the book restricts winners', () {
    // The single most important fact about professional betting, and the
    // game's antagonist: beating the closing line gets you limited, so
    // grinding a known edge forever is not the game.

    test('a break-even player is left alone', () {
      expect(policy.limitForPlayer(500, 0), 500);
      expect(policy.limitForPlayer(500, -0.05), 500);
      expect(policy.isRestricted(0), isFalse);
    });

    test('a player at the industry sharp threshold is still unrestricted', () {
      // 2% average CLV is the rule-of-thumb line between "lucky" and "sharp".
      expect(policy.isRestricted(0.02), isFalse);
      expect(policy.limitForPlayer(500, 0.02), 500);
    });

    test('beating the line consistently gets you cut', () {
      expect(policy.isRestricted(0.03), isTrue);
      expect(policy.limitForPlayer(500, 0.03), lessThan(500));
    });

    test('the sharper the player, the harder the cut', () {
      final mild = policy.limitForPlayer(500, 0.03);
      final sharp = policy.limitForPlayer(500, 0.06);
      final elite = policy.limitForPlayer(500, 0.12);
      expect(sharp, lessThan(mild));
      expect(elite, lessThan(sharp));
    });

    test('a restricted player is never cut to nothing', () {
      // A banned player has no game left, so the floor keeps them playing.
      // The decay approaches the floor asymptotically -- 500 -> 277 -> 119 ->
      // 55 -> 21 -> 7 across CLV 0.03..0.9 -- and clamps once it would go
      // under.
      expect(policy.limitForPlayer(500, 0.9), greaterThan(policy.minimumLimit));
      expect(policy.limitForPlayer(500, 5), policy.minimumLimit);
      expect(policy.limitForPlayer(500, 50), policy.minimumLimit);
    });

    test('restriction scales with the base limit', () {
      expect(
        policy.limitForPlayer(1000, 0.04),
        greaterThan(policy.limitForPlayer(100, 0.04)),
      );
    });
  });

  group('LimitPolicy.limitFor', () {
    const policy = LimitPolicy();

    test('nobody is flagged on fewer bets than the book needs to judge', () {
      expect(policy.limitFor(50, bets: 19, averageClv: 0.10), 50);
      expect(policy.restricts(bets: 19, averageClv: 0.10), isFalse);
    });

    test('a sharp record cuts the limit once there are enough bets', () {
      expect(
        policy.limitFor(50, bets: 20, averageClv: 0.05),
        policy.limitForPlayer(50, 0.05),
      );
      expect(policy.limitFor(50, bets: 20, averageClv: 0.05), lessThan(50));
      expect(policy.restricts(bets: 20, averageClv: 0.05), isTrue);
    });

    test('an ordinary record is left alone, however long', () {
      expect(policy.limitFor(50, bets: 500, averageClv: -0.01), 50);
      expect(policy.limitFor(50, bets: 500, averageClv: null), 50);
      expect(policy.restricts(bets: 500, averageClv: 0.01), isFalse);
    });
  });

  group('SeasonRunner limits', () {
    test('a bettor who beats the close is cut to the restricted limit', () {
      const policy = LimitPolicy();
      final season = const SeasonRunner().run(
        masterSeed: 11,
        bettor: const OracleBettor(),
      );
      final bets = season.bets;
      expect(bets.length, greaterThan(policy.restrictAfterBets + 10));
      var clvSum = 0.0;
      var restricted = 0;
      for (final (i, b) in bets.indexed) {
        final cap = policy.limitFor(
          50,
          bets: i,
          averageClv: i == 0 ? null : clvSum / i,
        );
        if (cap < 50) {
          restricted++;
        }
        clvSum += b.closingLineValue;
      }
      expect(restricted, greaterThan(0), reason: 'the oracle is never sharp?');
      // The limit is only re-read between matchdays, so check the LAST
      // matchday, which saw the whole season's record.
      final last = season.matchdays.lastWhere((d) => d.bets.isNotEmpty);
      for (final b in last.bets) {
        expect(b.bet.stake, lessThan(50));
      }
    });

    test('limits can be switched off', () {
      final season = const SeasonRunner(limits: null)
          .run(masterSeed: 11, bettor: const OracleBettor());
      expect(season.bets.map((b) => b.bet.stake), contains(50));
    });
  });
}
