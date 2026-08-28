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
}
