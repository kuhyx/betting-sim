/// The days of the week, Monday first.
///
/// The league plays one round a week. The other six days are what the life
/// sim needs to exist at all: without days between matches there is nowhere
/// to work, rest, or read up on the next round.
enum Weekday {
  /// Monday.
  monday('Mon'),

  /// Tuesday.
  tuesday('Tue'),

  /// Wednesday.
  wednesday('Wed'),

  /// Thursday.
  thursday('Thu'),

  /// Friday.
  friday('Fri'),

  /// Saturday, when the league plays.
  saturday('Sat'),

  /// Sunday.
  sunday('Sun');

  /// Creates a weekday displayed as [label].
  const Weekday(this.label);

  /// Three-letter label, for display.
  final String label;
}

/// How many days a week has. Named so the arithmetic below reads.
const int daysPerWeek = 7;

/// One day of a season, counted from the opening day.
///
/// An extension type rather than a class: a date IS its day index, so value
/// equality comes for free from `int` instead of from a hand-written `==`
/// that the linter would then want `package:meta` to vouch for. The engine
/// has no runtime dependencies and keeps it that way.
extension type const GameDate(int dayOfSeason) {
  /// Which week of the season this falls in. Zero-based.
  int get week => dayOfSeason ~/ daysPerWeek;

  /// Which day of the week this is.
  Weekday get weekday => Weekday.values[dayOfSeason % daysPerWeek];

  /// How this reads on screen, e.g. "Sat wk2".
  String get label => '${weekday.label} wk${week + 1}';
}

/// Maps the engine's matchday index onto a week-by-week season calendar.
///
/// A PROJECTION of the existing index, never a replacement for it. Fixture
/// scheduling, every `SeedPath` and the whole acceptance gate keep counting in
/// matchdays; this only decides which calendar day a matchday lands on. That
/// separation is deliberate -- if the calendar could move a fixture it would
/// change what the gate measures, and a save would no longer replay.
class SeasonCalendar {
  /// Creates a calendar for a season of [matchdays] rounds.
  const SeasonCalendar({
    required this.matchdays,
    this.matchWeekday = Weekday.saturday,
  });

  /// How many rounds the season has.
  final int matchdays;

  /// Which day of the week the league plays on.
  final Weekday matchWeekday;

  /// How many calendar days the season spans.
  int get totalDays => matchdays * daysPerWeek;

  /// Every date in the season, in order.
  List<GameDate> get days => List<GameDate>.generate(totalDays, GameDate.new);

  /// The date that matchday [matchday] is played on.
  GameDate dateOfMatchday(int matchday) =>
      GameDate(matchday * daysPerWeek + matchWeekday.index);

  /// The matchday played on [date], or null if the league is not playing.
  int? matchdayOn(GameDate date) {
    if (date.weekday != matchWeekday) {
      return null;
    }
    return date.week < matchdays ? date.week : null;
  }
}
