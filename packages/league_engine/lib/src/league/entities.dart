import 'package:league_engine/src/ratings/glicko2_types.dart';

/// A player on a club's roster.
///
/// Attributes are the *true* values. Nothing outside the engine may read them
/// directly: the player of the game sees scouted estimates and box scores, in
/// the same way OOTP shows a scout's assessment rather than the real rating.
class Player {
  /// Creates a player.
  const Player({
    required this.id,
    required this.name,
    required this.attack,
    required this.defence,
    required this.stamina,
    required this.age,
  });

  /// Stable identity within a save.
  final int id;

  /// Display name.
  final String name;

  /// Contribution to the club's scoring rate, roughly 0..100.
  final double attack;

  /// Contribution to suppressing the opponent's scoring rate, roughly 0..100.
  final double defence;

  /// How well the player holds performance across a match and a season.
  final double stamina;

  /// Age in years, which drives the development and decline curve.
  final int age;

  @override
  String toString() => 'Player($name)';
}

/// A club: a squad, a home town, and a rating.
class Team {
  /// Creates a team.
  const Team({
    required this.id,
    required this.name,
    required this.town,
    required this.players,
    required this.rating,
  });

  /// Stable identity within a save.
  final int id;

  /// Club name, e.g. "Ravenshambe United".
  final String name;

  /// Home town, which is also where its matches are played.
  final String town;

  /// The squad.
  final List<Player> players;

  /// The club's Glicko-2 rating. This is the system's *estimate*, derived
  /// from results -- not a readout of the squad's true attributes.
  final Rating rating;

  /// Mean attacking strength of the squad.
  double get attackStrength => _mean((p) => p.attack);

  /// Mean defensive strength of the squad.
  double get defenceStrength => _mean((p) => p.defence);

  double _mean(double Function(Player) f) {
    if (players.isEmpty) {
      return 0;
    }
    return players.map(f).reduce((a, b) => a + b) / players.length;
  }

  /// Returns a copy with the given fields replaced.
  Team copyWith({Rating? rating, List<Player>? players}) {
    return Team(
      id: id,
      name: name,
      town: town,
      players: players ?? this.players,
      rating: rating ?? this.rating,
    );
  }

  @override
  String toString() => 'Team($name)';
}

/// A scheduled match between two clubs on a given matchday.
class Fixture {
  /// Creates a fixture.
  const Fixture({
    required this.day,
    required this.homeId,
    required this.awayId,
  });

  /// Matchday index within the season.
  final int day;

  /// The home club's id. Home advantage attaches to this side.
  final int homeId;

  /// The away club's id.
  final int awayId;

  @override
  String toString() => 'Fixture(d$day: $homeId v $awayId)';
}

/// A whole league: its clubs and its fixture list.
class League {
  /// Creates a league.
  const League({required this.teams, required this.fixtures});

  /// Every club, in a stable order.
  final List<Team> teams;

  /// Every fixture of the season, ordered by matchday.
  final List<Fixture> fixtures;

  /// The number of matchdays in the season.
  int get matchdays =>
      fixtures.isEmpty ? 0 : fixtures.map((f) => f.day).reduce(_max) + 1;

  /// Returns the fixtures scheduled for [day].
  List<Fixture> fixturesOn(int day) =>
      fixtures.where((f) => f.day == day).toList();

  /// Looks a club up by id.
  Team teamById(int id) => teams.firstWhere((t) => t.id == id);

  static int _max(int a, int b) => a > b ? a : b;
}
