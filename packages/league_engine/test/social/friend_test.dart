import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

final _clubs = <int>[1, 2, 3, 4, 5];

void main() {
  group('generateFriends', () {
    final circle = generateFriends(20260828, _clubs);

    test('is the same people every time the save is opened', () {
      final again = generateFriends(20260828, _clubs);
      expect(again.map((f) => f.name), circle.map((f) => f.name));
      expect(again.map((f) => f.bias), circle.map((f) => f.bias));
      expect(again.map((f) => f.noise), circle.map((f) => f.noise));
    });

    test('numbers them and gives them names', () {
      expect(circle, hasLength(6));
      expect(circle.map((f) => f.id), <int>[0, 1, 2, 3, 4, 5]);
      expect(circle.every((f) => f.name.isNotEmpty), isTrue);
      expect(circle.first.toString(), startsWith('Friend('));
    });

    test('always contains one of every sort', () {
      // Guaranteed, not hoped for. Drawing each bias independently is uniform
      // ACROSS saves and lopsided WITHIN one: seed 20260828 once produced four
      // cagey friends, so three quarters of the circle only wanted the draw.
      for (var seed = 0; seed < 80; seed++) {
        expect(
          generateFriends(seed, _clubs).map((f) => f.bias).toSet(),
          FriendBias.values.toSet(),
          reason: 'save $seed',
        );
      }
    });

    test('does not hand out the biases in a fixed order', () {
      final firsts = <FriendBias>{
        for (var seed = 0; seed < 40; seed++)
          generateFriends(seed, _clubs).first.bias,
      };
      expect(firsts, hasLength(greaterThan(1)));
    });

    test('gives the loyal ones a real club to be loyal to', () {
      for (final friend in circle) {
        expect(_clubs, contains(friend.loyalClubId));
      }
    });

    test('copes with a league that has no clubs yet', () {
      expect(
        generateFriends(1, const <int>[]).every((f) => f.loyalClubId == -1),
        isTrue,
      );
    });

    test('keeps everybody roughly on the price', () {
      // These are your mates, not sharps. A friend far above zero would be
      // somebody whose bets you should simply always decline.
      for (var seed = 0; seed < 40; seed++) {
        for (final friend in generateFriends(seed, _clubs)) {
          expect(friend.awareness, inInclusiveRange(-0.06, 0.04));
          expect(friend.noise, inInclusiveRange(0.18, 0.55));
          expect(friend.chattiness, inInclusiveRange(0.12, 0.45));
          expect(friend.stubbornness, inInclusiveRange(0, 0.6));
        }
      }
    });

    test('honours a different circle shape', () {
      final crowd = generateFriends(
        3,
        _clubs,
        const FriendCircleConfig(count: 9, chattiness: (low: 1, high: 1)),
      );
      expect(crowd, hasLength(9));
      expect(crowd.every((f) => f.chattiness == 1), isTrue);
    });

    test('can be a circle smaller than the number of biases', () {
      final few = generateFriends(
        3,
        _clubs,
        const FriendCircleConfig(count: 2),
      );
      expect(few, hasLength(2));
      expect(few.map((f) => f.bias).toSet(), hasLength(2));
    });
  });

  group('perturbLogOdds', () {
    test('leaves a distribution a distribution', () {
      final moved = perturbLogOdds(
        const OutcomeProbs(home: 0.5, draw: 0.3, away: 0.2),
        0.4,
        Mix32Source(9),
      );
      expect(moved.asList.reduce((a, b) => a + b), closeTo(1, 1e-12));
      expect(moved.asList.every((p) => p > 0 && p < 1), isTrue);
    });

    test('moves a long price and a short one by the same proportion', () {
      // The reason it is log-odds and not additive: adding 0.06 to a 0.50
      // chance is a nudge, and to a 0.08 chance it is nearly a doubling. That
      // asymmetry is felt hardest by whoever is LAYING the long price.
      const base = OutcomeProbs(home: 0.80, draw: 0.12, away: 0.08);
      final ratios = <double>[];
      for (var seed = 0; seed < 400; seed++) {
        final moved = perturbLogOdds(base, 0.3, Mix32Source(seed));
        ratios.add(moved.away / base.away / (moved.home / base.home));
      }
      final mean = ratios.reduce((a, b) => a + b) / ratios.length;
      expect(mean, closeTo(1, 0.15));
    });

    test('does nothing at all when the noise is zero', () {
      const base = OutcomeProbs(home: 0.5, draw: 0.3, away: 0.2);
      final moved = perturbLogOdds(base, 0, Mix32Source(1));
      expect(moved.home, closeTo(base.home, 1e-9));
      expect(moved.away, closeTo(base.away, 1e-9));
    });
  });
}
