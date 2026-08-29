import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

const _config = LifeConfig();

void main() {
  group('payRent', () {
    test('takes the rent when you have it', () {
      final after = payRent(const Household(bankroll: 1000), _config);
      expect(after.bankroll, 1000 - _config.rentPerWeek);
      expect(after.arrears, 0);
      expect(after.ending, RunEnding.running);
      expect(after.housed, isTrue);
    });

    test('puts you behind when you do not', () {
      final after = payRent(const Household(bankroll: 10), _config);
      expect(after.bankroll, 10, reason: 'nothing was taken');
      expect(after.arrears, 1);
      expect(after.housed, isTrue, reason: 'one missed week is a warning');
    });

    test('arrears accumulate, so a bad month is a spiral', () {
      // Missing a week does not forgive it. That is what turns a run of bad
      // luck into something you can see coming.
      var house = const Household(bankroll: 10);
      house = payRent(house, _config);
      expect(house.arrears, 1);

      final owed = _config.rentPerWeek * 2;
      final caughtUp = payRent(
        house.copyWith(bankroll: owed),
        _config,
      );
      expect(caughtUp.bankroll, 0);
      expect(caughtUp.arrears, 0);
    });

    test('will not clear one week when two are owed', () {
      final house = payRent(const Household(bankroll: 10), _config);
      final stillShort = payRent(
        house.copyWith(bankroll: _config.rentPerWeek),
        _config,
      );
      expect(stillShort.arrears, 2);
      expect(stillShort.ending, RunEnding.evicted);
    });

    test('puts you out once you are past the allowance', () {
      var house = const Household(bankroll: 0);
      house = payRent(house, _config);
      expect(house.ending, RunEnding.running);
      house = payRent(house, _config);
      expect(house.ending, RunEnding.evicted);
      expect(house.housed, isFalse);
    });

    test('does nothing to somebody already put out', () {
      const gone = Household(bankroll: 5000, ending: RunEnding.evicted);
      expect(payRent(gone, _config).bankroll, 5000);
      expect(payRent(gone, _config).ending, RunEnding.evicted);
    });

    test('honours a harder landlord', () {
      const strict = LifeConfig(missedRentAllowance: 0);
      expect(
        payRent(const Household(bankroll: 0), strict).ending,
        RunEnding.evicted,
      );
    });
  });

  group('the shop', () {
    test('sells time, and never an edge', () {
      // Selling the edge would sell the only thing the game is about.
      expect(catalogue, isNotEmpty);
      for (final item in catalogue) {
        expect(item.cost, greaterThan(0));
        expect(item.name, isNotEmpty);
        expect(item.blurb, isNotEmpty);
        expect(
          item.hoursBack > 0 || item.stressRelief > 0,
          isTrue,
          reason: '${item.id} does nothing',
        );
      }
      expect(catalogue.map((i) => i.id).toSet(), hasLength(catalogue.length));
    });
  });

  group('Household', () {
    test('copies field by field', () {
      const house = Household(bankroll: 100, arrears: 2);
      expect(house.copyWith(bankroll: 5).bankroll, 5);
      expect(house.copyWith(bankroll: 5).arrears, 2);
      expect(house.copyWith(arrears: 0).arrears, 0);
      expect(house.copyWith().bankroll, 100);
      expect(house.copyWith(ending: RunEnding.survived).housed, isFalse);
    });
  });
}
