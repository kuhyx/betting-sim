import 'package:league_engine/league_engine.dart';

/// A squad of 18 with a spread of ability, so lineup order is unambiguous.
List<Player> squad(int base) => <Player>[
  for (var i = 0; i < 18; i++)
    Player(
      id: base + i,
      name: 'p${base + i}',
      attack: 40.0 + i,
      defence: 45.0 + (i % 7),
      stamina: 30.0 + i * 3,
      age: 20 + (i % 12),
    ),
];

/// A club.
Team club(int id, String name) => Team(
  id: id,
  name: name,
  town: 'Town$id',
  players: squad(id * 100),
  rating: const Rating(),
);

/// A match context with the modifiers set directly, rather than projected
/// from a `LatentState`. That is what lets a test move ONE hidden factor and
/// hold the other three still -- through `LatentModifiers` they arrive
/// blended, and nothing could be isolated.
MatchContext context({
  MatchModifiers home = const MatchModifiers(),
  MatchModifiers away = const MatchModifiers(),
  double refereeBias = 1,
  int seed = 4242,
}) => MatchContext(
  home: club(1, 'Home'),
  away: club(2, 'Away'),
  homeModifiers: home,
  awayModifiers: away,
  seedPath: SeedPath(master: seed, season: 0, day: 0, match: 0),
  refereeBias: refereeBias,
);

/// A finished 2-1, with the goals already placed.
MatchResult result() => const MatchResult(
  homeScore: 2,
  awayScore: 1,
  events: <MatchEvent>[
    GoalEvent(minute: 22, byHome: true, playerId: null),
    GoalEvent(minute: 54, byHome: false, playerId: null),
    GoalEvent(minute: 88, byHome: true, playerId: null),
  ],
);
