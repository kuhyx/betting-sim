import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/performance.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:flutter/foundation.dart';
import 'package:league_engine/league_engine.dart';

/// The playable slice: one league, one bankroll, one matchday at a time.
///
/// A thin controller over the engine. Deliberately holds no simulation logic
/// of its own -- everything here delegates, so the UI can never drift from the
/// engine the acceptance gate measures.
class GameState extends ChangeNotifier {
  /// Starts a new game from [masterSeed], priced by [tuning].
  GameState({this.masterSeed = 20260828, this.tuning = const Tuning()}) {
    _league = generateLeague(masterSeed);
    _states = <int, LatentState>{
      for (final t in _league.teams) t.id: const LatentState(),
    };
    _openDay();
  }

  /// The save's root seed.
  final int masterSeed;

  /// The balance knobs this game was generated under.
  ///
  /// Immutable: changing a knob changes pricing, so the fixtures already shown
  /// were quoted under the old one. Retuning constructs a fresh [GameState]
  /// rather than mutating this one -- see the debug settings surface.
  final Tuning tuning;

  /// The player's running ROI and CLV.
  final Performance performance = Performance();

  static const _clv = ClvCalculator();

  late final League _league;
  late Map<int, LatentState> _states;

  late final DixonColesModel _model = tuning.model;
  late final MatchRunner _runner = MatchRunner(
    model: _model,
    latentConfig: tuning.latentConfig,
  );
  late final LatentDecay _decay = LatentDecay(tuning.latentConfig);
  late final MarketMaker _maker = MarketMaker(
    model: _model,
    bookmaker: tuning.bookmaker,
    openingLine: const OpeningLine(),
    flow: const MoneyFlow(),
    bookLatentAwareness: tuning.bookLatentAwareness,
  );

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
        _settleBet(card, staked, result);
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

  void _settleBet(
    FixtureCard card,
    ({Selection selection, double stake}) staked,
    MatchResult result,
  ) {
    final bet = Bet(
      selection: staked.selection,
      stake: staked.stake,
      taken: card.market.priceOf(staked.selection),
    );
    final profit = settle(bet, result);
    final clv = _clv.forBet(
      selection: bet.selection,
      taken: bet.taken,
      closing: card.closing,
    );
    _bankroll += profit;
    performance.record(stake: staked.stake, profit: profit, clv: clv);
    _history.add(
      PlayerBet(
        fixture: '${card.home.name} v ${card.away.name}',
        selection: staked.selection,
        stake: staked.stake,
        taken: bet.taken,
        profit: profit,
        result: '${result.homeScore}-${result.awayScore}',
        closingLineValue: clv,
      ),
    );
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
    final markets = _maker.marketsFor(
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

  static MatchOutcome _outcomeFor(MatchResult result, {required bool isHome}) {
    if (result.drawn) {
      return MatchOutcome.draw;
    }
    return result.homeWon == isHome ? MatchOutcome.win : MatchOutcome.loss;
  }
}
