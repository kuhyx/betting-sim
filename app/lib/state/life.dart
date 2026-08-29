import 'package:league_engine/league_engine.dart';

/// A life, frozen for a save.
///
/// STORED rather than replayed, unlike the league. The fixtures and the
/// scorelines all come back from the seed; how you chose to spend a Tuesday
/// does not, any more than which of your friends' bets you took.
class LifeSnapshot {
  /// Creates a snapshot.
  const LifeSnapshot({
    required this.dayOfSeason,
    required this.lifeMoney,
    required this.arrears,
    required this.ending,
    required this.needs,
    required this.owned,
  });

  /// Which day of the season it was.
  final int dayOfSeason;

  /// What the living had cost or earned.
  final double lifeMoney;

  /// How many weeks' rent were owed.
  final int arrears;

  /// Whether the run was still going.
  final RunEnding ending;

  /// How you were holding up.
  final Needs needs;

  /// What had been bought.
  final Set<String> owned;
}

/// How the week is actually going.
///
/// Owns the clock. The rest of the game counts in MATCHDAYS; this counts in
/// days, and a matchday is simply the Saturday you eventually reach. That is
/// what makes the six days in between cost something: they are hours you
/// spend on work, or on football, and never on both.
class LifeState {
  /// Creates a life at the start of a season.
  LifeState({this.config = const LifeConfig()});

  /// Rates and prices.
  final LifeConfig config;

  /// The day the rent comes out.
  static const Weekday rentDay = Weekday.friday;

  /// How you are holding up.
  Needs needs = const Needs();

  /// Which day of the season it is.
  int dayOfSeason = 0;

  /// How many weeks' rent you are behind.
  int arrears = 0;

  /// Whether the run is over, and how.
  RunEnding ending = RunEnding.running;

  /// What the living has cost or earned, all season.
  ///
  /// Kept apart from the betting so a save has one source of truth for each:
  /// the bankroll is the opening balance plus this plus what the bets did,
  /// and no two of those can quietly disagree.
  double lifeMoney = 0;

  /// What you have bought.
  final Set<String> owned = <String>{};

  /// Today.
  GameDate get date => GameDate(dayOfSeason);

  /// How many hours you have to spend, once the shopping is accounted for.
  ///
  /// Items give hours BACK: a bicycle is an hour off the commute, a slow
  /// cooker an hour off the tea. Nothing in the shop improves a price -- what
  /// money buys is time, and time is what you read the feed with.
  int get hoursToday =>
      config.hoursPerDay +
      catalogue
          .where((i) => owned.contains(i.id))
          .fold(0, (sum, i) => sum + i.hoursBack);

  /// The stress the shopping takes off, every day.
  double get comfort => catalogue
      .where((i) => owned.contains(i.id))
      .fold(0, (sum, i) => sum + i.stressRelief);

  /// Whether the run is still going.
  bool get running => ending == RunEnding.running;

  /// Lives [plan], and returns what it did to the money.
  double live(List<Activity> plan) {
    final day = liveDay(needs, plan, config.copyWith(hoursPerDay: hoursToday));
    needs = day.needs.copyWith(stress: day.needs.stress - comfort);
    lifeMoney += day.money;
    dayOfSeason++;
    return day.money;
  }

  /// Settles the rent against [bankroll], and returns what it took.
  double settleRent(double bankroll) {
    final before = Household(
      bankroll: bankroll,
      arrears: arrears,
      ending: ending,
    );
    final after = payRent(before, config);
    arrears = after.arrears;
    ending = after.ending;
    final taken = after.bankroll - bankroll;
    lifeMoney += taken;
    return taken;
  }

  /// Buys [item] if it can be afforded and is not already owned.
  ///
  /// Returns what it cost, or zero if nothing happened.
  double buy(Purchase item, double bankroll) {
    if (owned.contains(item.id) || bankroll < item.cost) {
      return 0;
    }
    owned.add(item.id);
    lifeMoney -= item.cost;
    return -item.cost;
  }

  /// This life, frozen.
  LifeSnapshot get snapshot => LifeSnapshot(
    dayOfSeason: dayOfSeason,
    lifeMoney: lifeMoney,
    arrears: arrears,
    ending: ending,
    needs: needs,
    owned: Set<String>.of(owned),
  );

  /// Puts a saved life back.
  void restore(LifeSnapshot saved) {
    dayOfSeason = saved.dayOfSeason;
    lifeMoney = saved.lifeMoney;
    arrears = saved.arrears;
    ending = saved.ending;
    needs = saved.needs;
    owned
      ..clear()
      ..addAll(saved.owned);
  }

  /// Ends the run because the season did.
  void finish() {
    if (running) {
      ending = RunEnding.survived;
    }
  }
}
