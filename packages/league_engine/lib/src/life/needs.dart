/// The three things that run down while you are busy reading about football.
///
/// All on 0..1 so they can be shown as bars and reasoned about together.
/// [energy] and [fullness] are resources you spend; [stress] is a debt you
/// accumulate. None of them touches a price, a scoreline or a probability --
/// the life layer decides what you can AFFORD to do, never what happens when
/// you do it.
class Needs {
  /// Creates a state of being.
  const Needs({this.energy = 1, this.fullness = 1, this.stress = 0});

  /// How much you have left in you. At zero you can do nothing but sleep.
  final double energy;

  /// How recently you ate. At zero it starts costing energy.
  final double fullness;

  /// How wound up you are. High stress makes rest less restful.
  final double stress;

  /// Whether you are too far gone to do anything but sleep.
  bool get exhausted => energy <= 0;

  /// Whether you have gone too long without eating.
  bool get starving => fullness <= 0;

  /// Returns a copy with the given fields replaced, each clamped to its range.
  Needs copyWith({double? energy, double? fullness, double? stress}) => Needs(
    energy: (energy ?? this.energy).clamp(0.0, 1.0),
    fullness: (fullness ?? this.fullness).clamp(0.0, 1.0),
    stress: (stress ?? this.stress).clamp(0.0, 1.0),
  );

  @override
  String toString() =>
      'Needs(energy ${energy.toStringAsFixed(2)}, '
      'fullness ${fullness.toStringAsFixed(2)}, '
      'stress ${stress.toStringAsFixed(2)})';
}

/// Rates and prices for a life.
///
/// One frozen object, like `LatentConfig` and `NarrationConfig`, so the
/// balance lives in one readable place and a test can force a hard week
/// without hunting for one.
class LifeConfig {
  /// Creates a config. The defaults describe a life that is affordable if you
  /// work, and not if you do not.
  const LifeConfig({
    this.hoursPerDay = 24,
    this.wagePerHour = 11,
    this.shiftHours = 8,
    this.rentPerWeek = 320,
    this.mealCost = 9,
    this.mealFullness = 0.45,
    this.energyPerWakingHour = 0.035,
    this.energyPerSleepHour = 0.14,
    this.fullnessPerHour = 0.035,
    this.starvingEnergyPenalty = 0.06,
    this.stressPerWorkHour = 0.025,
    this.stressReliefPerHour = 0.035,
    this.stressRestPenalty = 0.5,
    this.missedRentAllowance = 1,
  });

  /// How many hours there are to spend. All of them, including the ones you
  /// sleep through -- a day you do not plan is a day you spend badly.
  final int hoursPerDay;

  /// What an hour of work pays.
  final double wagePerHour;

  /// The hours in a full shift.
  final int shiftHours;

  /// Rent, due once a week.
  final double rentPerWeek;

  /// What a meal costs.
  final double mealCost;

  /// How much of your hunger a meal settles.
  final double mealFullness;

  /// Energy spent per hour awake, whatever you are doing.
  final double energyPerWakingHour;

  /// Energy recovered per hour asleep, before stress.
  final double energyPerSleepHour;

  /// Fullness lost per hour, whatever you are doing.
  final double fullnessPerHour;

  /// Extra energy lost per hour once you have nothing left in the fridge.
  final double starvingEnergyPenalty;

  /// Stress gained per hour worked.
  final double stressPerWorkHour;

  /// Stress shed per hour of doing something you enjoy.
  final double stressReliefPerHour;

  /// How much of sleep's value stress takes away, at maximum stress.
  ///
  /// Not all of it. Being wound up makes rest worth less; it does not make
  /// sleep pointless, and a mechanic you cannot dig out of is a bad one.
  final double stressRestPenalty;

  /// How many weeks' rent you may miss before being put out.
  final int missedRentAllowance;

  /// Returns a copy with the given fields replaced.
  ///
  /// Exists for one caller: the app hands `liveDay` a longer day once you
  /// have bought the things that give hours back. Rewriting all fifteen
  /// fields by hand at that call site was worse than this.
  LifeConfig copyWith({int? hoursPerDay}) => LifeConfig(
    hoursPerDay: hoursPerDay ?? this.hoursPerDay,
    wagePerHour: wagePerHour,
    shiftHours: shiftHours,
    rentPerWeek: rentPerWeek,
    mealCost: mealCost,
    mealFullness: mealFullness,
    energyPerWakingHour: energyPerWakingHour,
    energyPerSleepHour: energyPerSleepHour,
    fullnessPerHour: fullnessPerHour,
    starvingEnergyPenalty: starvingEnergyPenalty,
    stressPerWorkHour: stressPerWorkHour,
    stressReliefPerHour: stressReliefPerHour,
    stressRestPenalty: stressRestPenalty,
    missedRentAllowance: missedRentAllowance,
  );
}
