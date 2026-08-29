import 'package:league_engine/src/league/calendar.dart';
import 'package:league_engine/src/life/activities.dart';
import 'package:league_engine/src/life/economy.dart';
import 'package:league_engine/src/life/needs.dart';

/// How somebody decides to spend a day.
abstract interface class DayPlanner {
  /// How this planner is labelled.
  String get name;

  /// The hours of [date], given how you are holding up.
  List<Activity> planFor(GameDate date, Needs needs);
}

/// How a life went.
class LifeResult {
  /// Creates a result.
  const LifeResult({
    required this.plannerName,
    required this.household,
    required this.needs,
    required this.daysLived,
    required this.everStarved,
  });

  /// Whose life it was.
  final String plannerName;

  /// Where the money and the tenancy ended up.
  final Household household;

  /// How you were holding up at the end.
  final Needs needs;

  /// How many days you got through.
  final int daysLived;

  /// Whether you ever ran the fridge to empty.
  final bool everStarved;

  /// Whether you were still standing at the whistle.
  bool get survived => household.ending == RunEnding.survived;
}

/// Lives a season, one day at a time, under a policy.
///
/// No RNG at all. The life layer is a BUDGET, not another thing to be unlucky
/// at: whether you can afford the rent should be a consequence of how you
/// spent your hours, and a player who does the arithmetic should not then be
/// evicted by a dice roll.
class LifeRunner {
  /// Creates a runner.
  const LifeRunner({
    this.config = const LifeConfig(),
    this.rentDay = Weekday.friday,
  });

  /// Rates and prices.
  final LifeConfig config;

  /// The day the rent comes out.
  final Weekday rentDay;

  /// Lives [calendar]'s whole season under [planner].
  LifeResult run({
    required SeasonCalendar calendar,
    required DayPlanner planner,
    double bankroll = 1000,
    Needs start = const Needs(),
  }) {
    var needs = start;
    var household = Household(bankroll: bankroll);
    var lived = 0;
    var starved = false;

    for (final date in calendar.days) {
      if (!household.housed) {
        break;
      }
      final day = liveDay(needs, planner.planFor(date, needs), config);
      needs = day.needs;
      starved = starved || needs.starving;
      household = household.copyWith(
        bankroll: household.bankroll + day.money,
      );
      if (date.weekday == rentDay) {
        household = payRent(household, config);
      }
      lived++;
    }

    return LifeResult(
      plannerName: planner.name,
      household: household.housed
          ? household.copyWith(ending: RunEnding.survived)
          : household,
      needs: needs,
      daysLived: lived,
      everStarved: starved,
    );
  }
}

/// Works for a living, eats, and sleeps.
///
/// The control that answers "is this life affordable at all". If somebody who
/// does everything right cannot make rent, the numbers are wrong and no amount
/// of clever betting would fix it.
class Grafter implements DayPlanner {
  /// Creates a grafter who spends [footballHours] a day on football.
  const Grafter({this.footballHours = 2, this.config = const LifeConfig()});

  /// Hours a day given over to reading and watching.
  final int footballHours;

  /// Rates, for shift length.
  final LifeConfig config;

  @override
  String get name => 'grafter';

  @override
  List<Activity> planFor(GameDate date, Needs needs) {
    final working =
        date.weekday != Weekday.saturday && date.weekday != Weekday.sunday;
    return <Activity>[
      for (var i = 0; i < 8; i++) Activity.sleep,
      Activity.eat,
      Activity.eat,
      if (working)
        for (var i = 0; i < config.shiftHours; i++) Activity.work,
      for (var i = 0; i < footballHours; i++) Activity.study,
    ];
  }
}

/// Never works. Reads about football instead.
///
/// The other control. A bankroll is not an income: this is what happens to
/// somebody who decides the betting will cover it.
class Idler implements DayPlanner {
  /// Creates an idler.
  const Idler();

  @override
  String get name => 'idler';

  @override
  List<Activity> planFor(GameDate date, Needs needs) => <Activity>[
    for (var i = 0; i < 8; i++) Activity.sleep,
    Activity.eat,
    Activity.eat,
    for (var i = 0; i < 8; i++) Activity.watch,
  ];
}
