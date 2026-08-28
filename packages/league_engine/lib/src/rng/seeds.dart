import 'package:league_engine/src/rng/mix32.dart';

/// An address in the seed tree: master -> season -> day -> match -> possession.
///
/// Levels are filled from the left; a null level means "not that deep".
class SeedPath {
  /// Creates a path. [master] is the only required level.
  const SeedPath({
    required this.master,
    this.season,
    this.day,
    this.match,
    this.possession,
  });

  /// The save's root seed. Every other value in the universe derives from it.
  final int master;

  /// Season index within the save.
  final int? season;

  /// Matchday index within the season.
  final int? day;

  /// Match index within the matchday.
  final int? match;

  /// Possession/event index within the match.
  final int? possession;

  /// Returns this path one level deeper.
  SeedPath child({int? season, int? day, int? match, int? possession}) {
    return SeedPath(
      master: master,
      season: season ?? this.season,
      day: day ?? this.day,
      match: match ?? this.match,
      possession: possession ?? this.possession,
    );
  }

  /// The levels present, in order, as (tag, value) pairs.
  ///
  /// The tag is what stops `(season 1, day 23)` colliding with
  /// `(season 12, day 3)`: each level is mixed under its own domain constant,
  /// so the same integer at two depths cannot produce the same seed.
  List<({int tag, int value})> get _levels {
    return <({int tag, int value})>[
      (tag: 0x4D, value: master),
      if (season != null) (tag: 0x53, value: season!),
      if (day != null) (tag: 0x44, value: day!),
      if (match != null) (tag: 0x43, value: match!),
      if (possession != null) (tag: 0x50, value: possession!),
    ];
  }

  @override
  String toString() {
    final parts = _levels.map((l) => l.value).join('/');
    return 'SeedPath($parts)';
  }
}

/// Derives the 32-bit seed for [path].
///
/// Pure and O(1) in the depth of the tree: reaching match (s, d, m) never
/// requires simulating the seasons or days before it. That is precisely the
/// property that lets one match be replayed without recomputing the universe,
/// and it is why a stream-spawning RNG API cannot be used here.
///
/// The mixing function is the in-repo 32-bit mixer rather than a
/// cryptographic hash: this is a decorrelation problem, not a security one,
/// and `package:crypto` ships no blake2b anyway. Each level is folded in under
/// its domain tag.
int deriveSeed(SeedPath path) {
  var acc = 0;
  for (final level in path._levels) {
    acc = mix32Next(u32(acc ^ level.tag)).value;
    acc = mix32Next(u32(acc ^ level.value)).value;
  }
  return acc;
}

/// A seed rendered as hex, for frozen-literal assertions.
String seedHex(SeedPath path) => hex32(deriveSeed(path));
