import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Weekday', () {
    test('is Monday-first and labelled', () {
      expect(Weekday.values, hasLength(daysPerWeek));
      expect(Weekday.monday.index, 0);
      expect(Weekday.saturday.index, 5);
      expect(
        Weekday.values.map((d) => d.label),
        <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
    });
  });

  group('GameDate', () {
    test('splits a day index into a week and a weekday', () {
      expect(const GameDate(0).week, 0);
      expect(const GameDate(0).weekday, Weekday.monday);
      expect(const GameDate(6).week, 0);
      expect(const GameDate(6).weekday, Weekday.sunday);
      expect(const GameDate(7).week, 1);
      expect(const GameDate(7).weekday, Weekday.monday);
    });

    test('reads as a weekday and a one-based week', () {
      expect(const GameDate(12).label, 'Sat wk2');
    });

    test('equality is by day index', () {
      expect(const GameDate(3), const GameDate(3));
      expect(const GameDate(3), isNot(const GameDate(4)));
      expect(const GameDate(3).hashCode, const GameDate(3).hashCode);
    });
  });

  group('SeasonCalendar', () {
    const calendar = SeasonCalendar(matchdays: 38);

    test('spans a week per matchday', () {
      expect(calendar.totalDays, 38 * 7);
      expect(calendar.days, hasLength(38 * 7));
      expect(calendar.days.first, const GameDate(0));
      expect(calendar.days.last, const GameDate(38 * 7 - 1));
    });

    test('plays every round on the same weekday', () {
      for (var day = 0; day < calendar.matchdays; day++) {
        final date = calendar.dateOfMatchday(day);
        expect(date.weekday, Weekday.saturday);
        expect(date.week, day);
        expect(date.dayOfSeason, lessThan(calendar.totalDays));
      }
    });

    test('round-trips a matchday through its date', () {
      for (var day = 0; day < calendar.matchdays; day++) {
        expect(calendar.matchdayOn(calendar.dateOfMatchday(day)), day);
      }
    });

    test('has no match on the six other days of the week', () {
      for (final weekday in Weekday.values) {
        final date = GameDate(weekday.index);
        final expected = weekday == Weekday.saturday ? 0 : null;
        expect(calendar.matchdayOn(date), expected, reason: '$weekday');
      }
    });

    test('has no match on a matchday weekday past the end of the season', () {
      const short = SeasonCalendar(matchdays: 2);
      expect(short.matchdayOn(short.dateOfMatchday(1)), 1);
      // The right weekday, but week 2 of a two-round season: no fixture.
      expect(short.matchdayOn(const GameDate(2 * 7 + 5)), isNull);
    });

    test('honours a different match weekday', () {
      const midweek = SeasonCalendar(
        matchdays: 4,
        matchWeekday: Weekday.wednesday,
      );
      expect(midweek.dateOfMatchday(0), const GameDate(2));
      expect(midweek.matchdayOn(const GameDate(2)), 0);
      expect(midweek.matchdayOn(const GameDate(5)), isNull);
    });
  });
}
