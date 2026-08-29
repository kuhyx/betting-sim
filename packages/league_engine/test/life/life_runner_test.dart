import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

const _calendar = SeasonCalendar(matchdays: 38);
const _runner = LifeRunner();

void main() {
  group('LifeRunner', () {
    test('somebody who works their shifts makes it to the whistle', () {
      // If the person doing everything right cannot make rent, the numbers
      // are wrong and no amount of clever betting would be a fix.
      final grafter = _runner.run(
        calendar: _calendar,
        planner: const Grafter(),
      );

      expect(grafter.survived, isTrue);
      expect(grafter.daysLived, _calendar.totalDays);
      expect(grafter.household.bankroll, greaterThan(0));
      expect(grafter.everStarved, isFalse);
      expect(grafter.needs.exhausted, isFalse);
      expect(grafter.plannerName, 'grafter');
    });

    test('and does not get rich doing it', () {
      // Deliberately tight. The job keeps a roof on; the betting is how you
      // actually get anywhere.
      final grafter = _runner.run(
        calendar: _calendar,
        planner: const Grafter(),
      );
      expect(grafter.household.bankroll, lessThan(2000));
    });

    test('somebody who stops working is put out long before the end', () {
      final idler = _runner.run(calendar: _calendar, planner: const Idler());

      expect(idler.survived, isFalse);
      expect(idler.household.ending, RunEnding.evicted);
      expect(idler.daysLived, lessThan(_calendar.totalDays / 4));
      expect(idler.plannerName, 'idler');
    });

    test('a bigger opening balance buys time, not a living', () {
      final rich = _runner.run(
        calendar: _calendar,
        planner: const Idler(),
        bankroll: 5000,
      );
      expect(rich.survived, isFalse);
      expect(rich.daysLived, greaterThan(26));
    });

    test('starts you wherever you say', () {
      final tired = _runner.run(
        calendar: _calendar,
        planner: const Grafter(),
        start: const Needs(energy: 0.1, fullness: 0.1),
      );
      expect(tired.daysLived, greaterThan(0));
    });

    test('the grafter works weekdays and not weekends', () {
      const grafter = Grafter();
      expect(
        grafter.planFor(const GameDate(0), const Needs()),
        contains(Activity.work),
      );
      // Saturday is a matchday, and the rest of the weekend is not a shift.
      expect(
        grafter.planFor(const GameDate(5), const Needs()),
        isNot(contains(Activity.work)),
      );
      expect(
        grafter.planFor(const GameDate(6), const Needs()),
        isNot(contains(Activity.work)),
      );
    });

    test('the idler never works at all', () {
      for (var day = 0; day < 7; day++) {
        expect(
          const Idler().planFor(GameDate(day), const Needs()),
          isNot(contains(Activity.work)),
        );
      }
    });

    test('stops the moment the tenancy does', () {
      // No point living out a season you have already been evicted from.
      final short =
          const LifeRunner(
            config: LifeConfig(missedRentAllowance: 0),
          ).run(
            calendar: _calendar,
            planner: const Idler(),
            bankroll: 0,
          );
      expect(short.daysLived, lessThan(10));
    });

    test('honours a different rent day', () {
      final monday = const LifeRunner(rentDay: Weekday.monday).run(
        calendar: const SeasonCalendar(matchdays: 2),
        planner: const Grafter(),
      );
      expect(monday.daysLived, 14);
    });
  });
}
