import 'package:league_engine/src/life/needs.dart';

/// Why a run stopped.
enum RunEnding {
  /// It has not.
  running,

  /// You could not cover the rent often enough.
  evicted,

  /// The season finished and you were still standing.
  survived,
}

/// Where you live, and whether you still do.
class Household {
  /// Creates a household.
  const Household({
    required this.bankroll,
    this.arrears = 0,
    this.ending = RunEnding.running,
  });

  /// What is in the account.
  final double bankroll;

  /// How many weeks' rent you are behind.
  final int arrears;

  /// Whether the run is over, and how.
  final RunEnding ending;

  /// Whether you are still in the game.
  bool get housed => ending == RunEnding.running;

  /// Returns a copy with the given fields replaced.
  Household copyWith({double? bankroll, int? arrears, RunEnding? ending}) =>
      Household(
        bankroll: bankroll ?? this.bankroll,
        arrears: arrears ?? this.arrears,
        ending: ending ?? this.ending,
      );
}

/// Settles the week's rent.
///
/// Arrears accumulate: missing a week does not forgive it, it adds to what you
/// owe next time. That is what turns a bad month into a spiral rather than a
/// series of independent bad weeks -- and a spiral you can see coming is the
/// stake the game was missing.
Household payRent(Household household, LifeConfig config) {
  if (!household.housed) {
    return household;
  }

  final owed = config.rentPerWeek * (household.arrears + 1);
  if (household.bankroll >= owed) {
    return household.copyWith(
      bankroll: household.bankroll - owed,
      arrears: 0,
    );
  }

  final behind = household.arrears + 1;
  return household.copyWith(
    arrears: behind,
    ending: behind > config.missedRentAllowance
        ? RunEnding.evicted
        : RunEnding.running,
  );
}

/// Something you can buy that gives you back TIME or INFORMATION.
///
/// Never edge. Nothing in the shop improves a price, a probability or a
/// scoreline, because selling the edge would sell the only thing the game is
/// actually about. What money buys is hours, and hours are what you read the
/// feed with.
class Purchase {
  /// Creates an item.
  const Purchase({
    required this.id,
    required this.name,
    required this.cost,
    required this.blurb,
    this.hoursBack = 0,
    this.stressRelief = 0,
  });

  /// Stable identity.
  final String id;

  /// What it is called.
  final String name;

  /// What it costs, once.
  final double cost;

  /// What it does, in words.
  final String blurb;

  /// Hours it hands back every day.
  final int hoursBack;

  /// Stress it takes off every day.
  final double stressRelief;
}

/// The shop. Small on purpose: four things, all of them time.
const List<Purchase> catalogue = <Purchase>[
  Purchase(
    id: 'bicycle',
    name: 'a bicycle',
    cost: 180,
    blurb: 'an hour a day back off the commute.',
    hoursBack: 1,
  ),
  Purchase(
    id: 'cooker',
    name: 'a slow cooker',
    cost: 90,
    blurb: 'an hour a day back off cooking.',
    hoursBack: 1,
  ),
  Purchase(
    id: 'telly',
    name: 'a decent telly',
    cost: 420,
    blurb: 'watch a match properly. an hour a day back.',
    hoursBack: 1,
  ),
  Purchase(
    id: 'chair',
    name: 'a chair that does not hurt',
    cost: 260,
    blurb: 'takes the edge off a long week.',
    stressRelief: 0.04,
  ),
];
