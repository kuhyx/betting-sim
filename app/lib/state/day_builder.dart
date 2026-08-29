import 'package:betting_sim/state/cards.dart';
import 'package:league_engine/league_engine.dart';

/// Turns a matchday's fixtures into the cards the player bets into.
///
/// Split out of `GameState` so that the controller holds *state* and this
/// holds the one derivation that needs the engine's whole pricing path. It
/// owns no mutable state of its own, which is what makes reopening a day
/// after a replay produce byte-identical prices.
class DayBuilder {
  /// Creates a builder over an already-configured engine.
  const DayBuilder({
    required this.runner,
    required this.maker,
    required this.masterSeed,
  });

  /// Builds match contexts and plays them.
  final MatchRunner runner;

  /// Quotes the opening and closing lines.
  final MarketMaker maker;

  /// The save's root seed, the top of every seed path below.
  final int masterSeed;

  /// The cards for matchday [day] of [league], given each club's hidden
  /// [states].
  List<FixtureCard> cardsFor({
    required League league,
    required int day,
    required Map<int, LatentState> states,
  }) {
    return <FixtureCard>[
      for (final (index, fixture) in league.fixturesOn(day).indexed)
        _cardFor(
          index: index,
          fixture: fixture,
          league: league,
          day: day,
          states: states,
        ),
    ];
  }

  FixtureCard _cardFor({
    required int index,
    required Fixture fixture,
    required League league,
    required int day,
    required Map<int, LatentState> states,
  }) {
    final home = league.teamById(fixture.homeId);
    final away = league.teamById(fixture.awayId);
    final path = SeedPath(
      master: masterSeed,
      season: 0,
      day: day,
      match: index,
    );
    final ctx = runner.contextFor(
      home: home,
      away: away,
      homeState: states[home.id]!,
      awayState: states[away.id]!,
      seedPath: path,
    );
    final markets = maker.marketsFor(
      ctx: ctx,
      home: home,
      away: away,
      path: path,
    );
    return FixtureCard(
      home: home,
      away: away,
      market: markets.opening,
      closing: markets.closing,
      context: ctx,
      index: index,
    );
  }
}
