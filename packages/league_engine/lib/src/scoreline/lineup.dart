import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/narration_config.dart';

/// Who played and who did not.
///
/// Injuries' one directly READABLE fingerprint. Every other hidden factor
/// leaks only as a number in a box score; this one has names in it, which is
/// what makes team news worth reading.
class TeamSheet {
  /// Creates a sheet.
  const TeamSheet({required this.starting, required this.missing});

  /// The players who started.
  final List<Player> starting;

  /// The first-choice players who were unavailable.
  final List<Player> missing;
}

/// Picks the strongest available XI, leaving [missingCount] out injured.
///
/// Consumes NO randomness at all, on purpose: the narrator's total draw count
/// has to be a deterministic function of the goal, foul and injury counts, or
/// a scripted test cannot know how long its queues need to be.
///
/// The `id` tie-break is not tidiness. `List.sort` is not documented as
/// stable in Dart, so two equally-rated players could order differently on the
/// VM and in JavaScript -- and `scripts/check_rng_parity.sh` requires the two
/// to agree bit for bit.
TeamSheet pickLineup(
  Team team, {
  required int missingCount,
  NarrationConfig config = const NarrationConfig(),
}) {
  final ranked = List<Player>.of(team.players)
    ..sort((a, b) {
      final byQuality = (b.attack + b.defence).compareTo(a.attack + a.defence);
      return byQuality != 0 ? byQuality : a.id.compareTo(b.id);
    });

  final out = missingCount.clamp(0, ranked.length);
  return TeamSheet(
    missing: ranked.take(out).toList(),
    starting: ranked.skip(out).take(config.lineupSize).toList(),
  );
}

/// Picks one player from [pool], each weighted by [weight].
///
/// Inverse-transform over a cumulative walk, exactly one uniform draw, never
/// rejection sampling -- a "reroll until valid" loop would make the draw count
/// depend on luck and break scripted tests.
///
/// Returns null for an empty pool rather than throwing: a club with its whole
/// squad unavailable is a legal state, and `GoalEvent.playerId` is already
/// nullable for it.
Player? pickWeighted(
  List<Player> pool,
  double Function(Player) weight,
  RandomSource rng,
) {
  if (pool.isEmpty) {
    return null;
  }

  var total = 0.0;
  for (final p in pool) {
    total += weight(p);
  }

  // The last player is the loop's fall-through rather than an iteration, so
  // rounding drift at the top of the range cannot leave the walk with nobody
  // to return.
  var target = rng.uniform01() * total;
  for (var i = 0; i < pool.length - 1; i++) {
    target -= weight(pool[i]);
    if (target <= 0) {
      return pool[i];
    }
  }
  return pool.last;
}
