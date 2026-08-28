import 'package:flutter/foundation.dart';
import 'package:league_engine/league_engine.dart';

/// A fixture as the player sees it: the two clubs and the prices on offer.
class FixtureCard {
  /// Creates a fixture card.
  const FixtureCard({
    required this.home,
    required this.away,
    required this.market,
    required this.context,
    required this.index,
  });

  /// The home club.
  final Team home;

  /// The away club.
  final Team away;

  /// The prices.
  final Market market;

  /// Everything needed to play the match.
  final MatchContext context;

  /// Which fixture on the matchday this is.
  final int index;
}

/// A bet the player has struck, once settled.
class PlayerBet {
  /// Creates a settled player bet.
  const PlayerBet({
    required this.fixture,
    required this.selection,
    required this.stake,
    required this.taken,
    required this.profit,
    required this.result,
  });

  /// What was backed.
  final String fixture;

  /// Which outcome.
  final Selection selection;

  /// How much was staked.
  final double stake;

  /// The price taken.
  final Odds taken;

  /// Profit, negative for a loss.
  final double profit;

  /// The final score.
  final String result;

  /// Whether the bet won.
  bool get won => profit > 0;
}

/// The playable slice: one league, one bankroll, one matchday at a time.
///
/// A thin controller over the engine. Deliberately holds no simulation logic
/// of its own -- everything here delegates, so the UI can never drift from the
/// engine the acceptance gate measures.
class GameState extends ChangeNotifier {
  /// Starts a new game from [masterSeed].
  GameState({this.masterSeed = 20260828}) {
    _league = generateLeague(masterSeed);
    _states = <int, LatentState>{
      for (final t in _league.teams) t.id: const LatentState(),
    };
    _openDay();
  }

  /// The save's root seed.
  final int masterSeed;

  static const _model = DixonColesModel();
  static const _runner = MatchRunner(model: _model);
  static const _decay = LatentDecay();
  static const _maker = MarketMaker(
    model: _model,
    bookmaker: Bookmaker(),
    openingLine: OpeningLine(),
    flow: MoneyFlow(),
    bookLatentAwareness: 0.7,
  );

  late final League _league;
  late Map<int, LatentState> _states;

  int _day = 0;
  double _bankroll = 1000;
  List<FixtureCard> _fixtures = <FixtureCard>[];
  final List<PlayerBet> _history = <PlayerBet>[];
  final Map<int, ({Selection selection, double stake})> _slip =
      <int, ({Selection selection, double stake})>{};

  /// Which matchday is showing.
  int get day => _day;

  /// How many matchdays the season has.
  int get totalDays => _league.matchdays;

  /// The player's money.
  double get bankroll => _bankroll;

  /// Today's fixtures and prices.
  List<FixtureCard> get fixtures => List.unmodifiable(_fixtures);

  /// Every settled bet, most recent first.
  List<PlayerBet> get history => List.unmodifiable(_history.reversed);

  /// The bets staked but not yet settled.
  Map<int, ({Selection selection, double stake})> get slip =>
      Map.unmodifiable(_slip);

  /// Whether the season has finished.
  bool get seasonOver => _day >= _league.matchdays;

  /// Total staked on the current slip.
  double get slipStake => _slip.values.fold(0, (sum, b) => sum + b.stake);

  /// Adds or replaces a selection on the slip.
  void stake(int fixtureIndex, Selection selection, double amount) {
    if (amount <= 0) {
      _slip.remove(fixtureIndex);
    } else {
      _slip[fixtureIndex] = (selection: selection, stake: amount);
    }
    notifyListeners();
  }

  /// Plays the matchday, settles the slip and moves on.
  void advanceDay() {
    if (seasonOver) {
      return;
    }

    for (final card in _fixtures) {
      final result = _runner.run(card.context);
      final staked = _slip[card.index];

      if (staked != null) {
        final bet = Bet(
          selection: staked.selection,
          stake: staked.stake,
          taken: card.market.priceOf(staked.selection),
        );
        final profit = settle(bet, result);
        _bankroll += profit;
        _history.add(
          PlayerBet(
            fixture: '${card.home.name} v ${card.away.name}',
            selection: staked.selection,
            stake: staked.stake,
            taken: bet.taken,
            profit: profit,
            result: '${result.homeScore}-${result.awayScore}',
          ),
        );
      }

      _states[card.home.id] = _decay.afterMatch(
        _states[card.home.id]!,
        _outcomeFor(result, isHome: true),
      );
      _states[card.away.id] = _decay.afterMatch(
        _states[card.away.id]!,
        _outcomeFor(result, isHome: false),
      );
    }

    for (final team in _league.teams) {
      _states[team.id] = _decay.rest(_states[team.id]!);
    }

    _slip.clear();
    _day++;
    if (!seasonOver) {
      _openDay();
    } else {
      _fixtures = <FixtureCard>[];
    }
    notifyListeners();
  }

  void _openDay() {
    _fixtures = <FixtureCard>[
      for (final (index, fixture) in _league.fixturesOn(_day).indexed)
        _cardFor(index, fixture),
    ];
  }

  FixtureCard _cardFor(int index, Fixture fixture) {
    final home = _league.teamById(fixture.homeId);
    final away = _league.teamById(fixture.awayId);
    final path = SeedPath(
      master: masterSeed,
      season: 0,
      day: _day,
      match: index,
    );
    final ctx = _runner.contextFor(
      home: home,
      away: away,
      homeState: _states[home.id]!,
      awayState: _states[away.id]!,
      seedPath: path,
    );
    return FixtureCard(
      home: home,
      away: away,
      market: _maker
          .marketsFor(ctx: ctx, home: home, away: away, path: path)
          .opening,
      context: ctx,
      index: index,
    );
  }

  static MatchOutcome _outcomeFor(MatchResult result, {required bool isHome}) {
    if (result.drawn) {
      return MatchOutcome.draw;
    }
    return result.homeWon == isHome ? MatchOutcome.win : MatchOutcome.loss;
  }
}
