import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/league/name_corpus.dart';
import 'package:league_engine/src/league/names.dart';
import 'package:league_engine/src/league/schedule.dart';
import 'package:league_engine/src/ratings/glicko2_types.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';

/// Shape of a generated league.
class LeagueConfig {
  /// Creates a config.
  const LeagueConfig({
    this.teamCount = 20,
    this.squadSize = 18,
    this.meanAbility = 50,
    this.abilitySpread = 12,
    this.minAge = 18,
    this.maxAge = 35,
  });

  /// How many clubs. 20 gives a 38-matchday season, as in real football.
  final int teamCount;

  /// Players per club.
  final int squadSize;

  /// Centre of the ability distribution.
  final double meanAbility;

  /// Standard deviation of club quality.
  ///
  /// This is the single most important balance knob in the whole engine: it
  /// sets how much talent separates the league, and therefore whether a
  /// season is long enough for skill to beat noise.
  final double abilitySpread;

  /// Youngest generated player.
  final int minAge;

  /// Oldest generated player.
  final int maxAge;
}

/// Builds a whole league from a master seed.
///
/// Deterministic: the same seed always yields the same clubs, squads and
/// fixture list, which is what lets a save be a seed plus deltas.
League generateLeague(
  int masterSeed, [
  LeagueConfig config = const LeagueConfig(),
]) {
  final rootPath = SeedPath(master: masterSeed);
  final rng = Mix32Source(deriveSeed(rootPath));

  final townNamer = MarkovNamer(townCorpus);
  final surnameNamer = MarkovNamer(surnameCorpus);
  final forenameNamer = MarkovNamer(forenameCorpus);

  final usedTowns = <String>{};
  final teams = <Team>[];
  var playerId = 0;

  for (var t = 0; t < config.teamCount; t++) {
    var town = townNamer.generate(rng, minLength: 6);
    // Two clubs from the same invented town would read as a bug.
    var guard = 0;
    while (!usedTowns.add(town) && guard++ < 50) {
      town = townNamer.generate(rng, minLength: 6);
    }

    final suffix = clubSuffixes[rng.randint(0, clubSuffixes.length - 1)];
    final quality = rng.normal(config.meanAbility, config.abilitySpread);

    final players = <Player>[
      for (var p = 0; p < config.squadSize; p++)
        Player(
          id: playerId++,
          name:
              '${forenameNamer.generate(rng)} '
              '${surnameNamer.generate(rng)}',
          // Individual ability varies around the club's level, so a weak club
          // can still field one standout -- which is what makes scouting a
          // squad worth doing rather than just reading the table.
          attack: _clamp(rng.normal(quality, 8)),
          defence: _clamp(rng.normal(quality, 8)),
          stamina: _clamp(rng.normal(70, 12)),
          age: rng.randint(config.minAge, config.maxAge),
        ),
    ];

    teams.add(
      Team(
        id: t,
        name: '$town $suffix',
        town: town,
        players: players,
        // Every club starts at the default rating with maximum RD: the system
        // has seen no results yet, and must not pretend otherwise.
        rating: const Rating(),
      ),
    );
  }

  return League(
    teams: teams,
    fixtures: buildSchedule(teams.map((t) => t.id).toList()),
  );
}

double _clamp(double v) => v < 1 ? 1 : (v > 99 ? 99 : v);
