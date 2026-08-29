import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

const _config = LifeConfig();

List<Activity> _hours(Activity activity, int count) => <Activity>[
  for (var i = 0; i < count; i++) activity,
];

void main() {
  group('Needs', () {
    test('clamps to its own range', () {
      const needs = Needs();
      expect(needs.copyWith(energy: 5).energy, 1);
      expect(needs.copyWith(energy: -5).energy, 0);
      expect(needs.copyWith(fullness: 9).fullness, 1);
      expect(needs.copyWith(stress: -1).stress, 0);
      expect(needs.copyWith(stress: 9).stress, 1);
      expect(needs.copyWith().energy, 1);
    });

    test('knows when you are done for', () {
      expect(const Needs().exhausted, isFalse);
      expect(const Needs().starving, isFalse);
      expect(const Needs(energy: 0).exhausted, isTrue);
      expect(const Needs(fullness: 0).starving, isTrue);
      expect(const Needs().toString(), contains('energy 1.00'));
    });
  });

  group('LifeConfig', () {
    test('copies with a longer day, and carries everything else', () {
      // The app hands `liveDay` a longer day once you have bought the things
      // that give hours back; nothing else about the life may change with it.
      final longer = _config.copyWith(hoursPerDay: 26);
      expect(longer.hoursPerDay, 26);
      expect(longer.wagePerHour, _config.wagePerHour);
      expect(longer.rentPerWeek, _config.rentPerWeek);
      expect(longer.mealCost, _config.mealCost);
      expect(longer.stressRestPenalty, _config.stressRestPenalty);
      expect(longer.missedRentAllowance, _config.missedRentAllowance);
      expect(longer.starvingEnergyPenalty, _config.starvingEnergyPenalty);
      expect(_config.copyWith().hoursPerDay, _config.hoursPerDay);
    });
  });

  group('effectOf', () {
    test('only work pays, and only sleep restores', () {
      expect(effectOf(Activity.work, _config).money, greaterThan(0));
      expect(effectOf(Activity.eat, _config).money, lessThan(0));
      expect(effectOf(Activity.sleep, _config).energy, greaterThan(0));
      for (final activity in Activity.values) {
        if (activity != Activity.sleep) {
          expect(
            effectOf(activity, _config).energy,
            lessThan(0),
            reason: '$activity',
          );
        }
      }
    });

    test('football is the only thing that takes the edge off', () {
      expect(effectOf(Activity.study, _config).stress, lessThan(0));
      expect(effectOf(Activity.watch, _config).stress, lessThan(0));
      expect(effectOf(Activity.work, _config).stress, greaterThan(0));
      expect(effectOf(Activity.idle, _config).stress, 0);
    });

    test('everything makes you hungry except eating', () {
      expect(effectOf(Activity.eat, _config).fullness, greaterThan(0));
      for (final activity in Activity.values) {
        if (activity != Activity.eat) {
          expect(effectOf(activity, _config).fullness, lessThan(0));
        }
      }
    });
  });

  group('liveDay', () {
    test('a shift pays a shift', () {
      final day = liveDay(
        const Needs(),
        _hours(Activity.work, 8),
        _config,
      );
      expect(day.money, closeTo(8 * _config.wagePerHour, 1e-9));
    });

    test('fills an unplanned day with doing nothing', () {
      // A day you do not plan is a day you spend badly, which is the honest
      // version of "nothing happened".
      final short = liveDay(const Needs(), _hours(Activity.work, 8), _config);
      final full = liveDay(
        const Needs(),
        <Activity>[..._hours(Activity.work, 8), ..._hours(Activity.idle, 16)],
        _config,
      );
      expect(short.needs.energy, closeTo(full.needs.energy, 1e-9));
      expect(short.money, closeTo(full.money, 1e-9));
    });

    test('ignores hours you cannot fit in a day', () {
      final day = liveDay(const Needs(), _hours(Activity.work, 40), _config);
      expect(day.money, closeTo(24 * _config.wagePerHour, 1e-9));
    });

    test('stress makes rest worth less, but never worthless', () {
      // An eight-hour day, so there are no unplanned hours afterwards to
      // muddy it -- an earlier version compared two full days and both had
      // hit the energy ceiling, so it was measuring the clamp.
      const night = LifeConfig(hoursPerDay: 8);
      double slept(double stress) => liveDay(
        // Starting empty, so neither run hits the energy ceiling.
        Needs(energy: 0, stress: stress),
        _hours(Activity.sleep, 8),
        night,
      ).needs.energy;

      expect(slept(1), lessThan(slept(0)));
      // Being wound up makes sleep worth less. It never makes it pointless,
      // because a hole you cannot climb out of is a bad mechanic.
      expect(
        slept(1),
        greaterThan(
          liveDay(
            const Needs(energy: 0),
            _hours(Activity.idle, 8),
            night,
          ).needs.energy,
        ),
      );
    });

    test('an empty fridge costs you on top of whatever you were doing', () {
      final fed = liveDay(
        const Needs(energy: 0.9),
        _hours(Activity.idle, 8),
        _config,
      );
      final hungry = liveDay(
        const Needs(energy: 0.9, fullness: 0),
        _hours(Activity.idle, 8),
        _config,
      );
      expect(hungry.needs.energy, lessThan(fed.needs.energy));
    });

    test('eating settles it and costs money', () {
      final day = liveDay(
        const Needs(fullness: 0.1),
        <Activity>[Activity.eat, Activity.eat],
        _config,
      );
      expect(day.needs.fullness, greaterThan(0.1));
      expect(day.money, closeTo(-2 * _config.mealCost, 1e-9));
    });

    test('somebody with nothing left cannot work', () {
      // The moment energy has teeth. A shift you cannot stay awake for pays
      // nothing, and the wages are what the rent comes out of -- so running
      // yourself into the ground is a spiral rather than a bad afternoon.
      final spent = liveDay(
        const Needs(energy: 0),
        _hours(Activity.work, 8),
        _config,
      );
      expect(spent.money, 0, reason: 'no pay for a shift you slept through');
      expect(spent.needs.energy, greaterThan(0), reason: 'you did sleep');

      // And somebody who still has something left is paid as normal.
      final fresh = liveDay(
        const Needs(energy: 0.5),
        _hours(Activity.work, 8),
        _config,
      );
      expect(fresh.money, closeTo(8 * _config.wagePerHour, 1e-9));
    });

    test('collapsing mid-shift stops the pay from that hour on', () {
      // Paid up to the point you gave out, and nothing after it: an hour's
      // kip does not put you back on the floor.
      const config = LifeConfig(hoursPerDay: 12);
      final day = liveDay(
        const Needs(energy: 0.05),
        _hours(Activity.work, 12),
        config,
      );
      expect(day.money, greaterThan(0));
      expect(day.money, lessThan(12 * config.wagePerHour));
    });

    test('honours a different length of day', () {
      const short = LifeConfig(hoursPerDay: 4);
      final day = liveDay(const Needs(), _hours(Activity.work, 8), short);
      expect(day.money, closeTo(4 * short.wagePerHour, 1e-9));
    });
  });
}
