import 'package:league_engine/src/life/needs.dart';

/// What you can spend an hour on.
///
/// Deliberately few. The point of the life layer is not a rich simulation of
/// chores, it is that reading up on football COSTS you the hour you would
/// have been paid for -- so information has a price and the bankroll has a
/// floor you can actually fall through.
enum Activity {
  /// Paid work.
  work,

  /// Sleep. The only thing that puts energy back.
  sleep,

  /// Eating, which costs money and time and settles your hunger.
  eat,

  /// Reading the feed: tips, forum threads, keeping your records.
  study,

  /// Watching a match you have money on, or want to understand.
  watch,

  /// Doing nothing in particular.
  idle,
}

/// What an hour of something does to you.
class HourEffect {
  /// Creates an effect.
  const HourEffect({
    this.energy = 0,
    this.fullness = 0,
    this.stress = 0,
    this.money = 0,
  });

  /// Energy per hour, signed.
  final double energy;

  /// Fullness per hour, signed.
  final double fullness;

  /// Stress per hour, signed.
  final double stress;

  /// Money per hour, signed.
  final double money;
}

/// The effect of one hour of [activity].
///
/// A table rather than a switch full of arithmetic, so the balance is
/// readable at a glance and a test can assert the shape of it.
HourEffect effectOf(Activity activity, LifeConfig config) => switch (activity) {
  Activity.work => HourEffect(
    energy: -config.energyPerWakingHour,
    fullness: -config.fullnessPerHour,
    stress: config.stressPerWorkHour,
    money: config.wagePerHour,
  ),
  Activity.sleep => HourEffect(
    energy: config.energyPerSleepHour,
    fullness: -config.fullnessPerHour,
  ),
  Activity.eat => HourEffect(
    energy: -config.energyPerWakingHour,
    fullness: config.mealFullness,
    money: -config.mealCost,
  ),
  Activity.study => HourEffect(
    energy: -config.energyPerWakingHour,
    fullness: -config.fullnessPerHour,
    stress: -config.stressReliefPerHour,
  ),
  Activity.watch => HourEffect(
    energy: -config.energyPerWakingHour,
    fullness: -config.fullnessPerHour,
    stress: -config.stressReliefPerHour,
  ),
  Activity.idle => HourEffect(
    energy: -config.energyPerWakingHour,
    fullness: -config.fullnessPerHour,
  ),
};

/// One day's living, done an hour at a time.
///
/// Hour by hour rather than in one arithmetic step, because the order matters:
/// going hungry costs you energy, and whether you were hungry depends on
/// whether you had already eaten that day.
class DayOutcome {
  /// Creates an outcome.
  const DayOutcome({required this.needs, required this.money});

  /// How you ended up.
  final Needs needs;

  /// What the day did to your bankroll.
  final double money;
}

/// Lives one day of [hours], in the order given.
///
/// Unallocated hours are spent idling: a day you do not plan is a day you
/// spend badly, which is the honest version of "nothing happened".
///
/// Hour by hour rather than in one step, because the order matters twice
/// over: going hungry costs energy, and running out of energy costs you the
/// shift you were in the middle of.
DayOutcome liveDay(
  Needs start,
  List<Activity> hours,
  LifeConfig config,
) {
  var needs = start;
  var money = 0.0;

  final schedule = <Activity>[
    ...hours.take(config.hoursPerDay),
    for (var i = hours.length; i < config.hoursPerDay; i++) Activity.idle,
  ];

  var collapsed = false;

  for (final planned in schedule) {
    // Once you have given out, the rest of the shift is gone: you were sent
    // home, and an hour's kip does not put you back on the floor. Latching it
    // for the day is what gives energy teeth -- without it, collapsing cost
    // one hour in eight and nothing else.
    collapsed = collapsed || needs.exhausted;
    final activity = collapsed && planned == Activity.work
        ? Activity.sleep
        : planned;
    final effect = effectOf(activity, config);
    // Stress makes rest worth less, but never worthless.
    final rested = activity == Activity.sleep
        ? effect.energy * (1 - config.stressRestPenalty * needs.stress)
        : effect.energy;
    // An empty stomach costs you on top of whatever you were doing.
    final hungry = needs.starving ? config.starvingEnergyPenalty : 0.0;

    needs = needs.copyWith(
      energy: needs.energy + rested - hungry,
      fullness: needs.fullness + effect.fullness,
      stress: needs.stress + effect.stress,
    );
    money += effect.money;
  }

  return DayOutcome(needs: needs, money: money);
}
