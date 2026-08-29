import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/day_builder.dart';
import 'package:betting_sim/state/performance.dart';
import 'package:betting_sim/state/save.dart';
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

  /// Rebuilds the game [save] describes, by REPLAYING it.
  ///
  /// A save carries no league, no hidden state and no scorelines, so there is
  /// nothing to load: the only way back to matchday N is to play matchdays 0
  /// to N-1 again from the same seed. That is the point of the seed-plus-
  /// deltas format -- if replay ever diverged, this constructor would be the
  /// thing that noticed, rather than a save silently disagreeing with itself.
  factory GameState.fromSave(SaveData save) {
    final game = GameState(masterSeed: save.masterSeed, tuning: save.tuning);
    for (var i = 0; i < save.day; i++) {
      game.advanceDay();
    }
    save.bets.forEach(game._replay);
    return game;
  }

  /// What every game starts with.
  static const double openingBankroll = 1000;

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

  late final DayBuilder _builder = DayBuilder(
    runner: _runner,
    maker: _maker,
    masterSeed: masterSeed,
  );

  /// Which calendar day each matchday falls on.
  late final SeasonCalendar calendar = SeasonCalendar(
    matchdays: _league.matchdays,
  );

  int _day = 0;
  double _bankroll = openingBankroll;
  List<FixtureCard> _fixtures = <FixtureCard>[];
  final List<PlayerBet> _history = <PlayerBet>[];
  final Map<int, ({Selection selection, double stake})> _slip =
      <int, ({Selection selection, double stake})>{};

  /// Which matchday is showing.
  int get day => _day;

  /// How many matchdays the season has.
  int get totalDays => _league.matchdays;

  /// Today's date. The season runs a round a week; the other six days are
  /// where everything that is not a match happens.
  GameDate get date => calendar.dateOfMatchday(_day.clamp(0, totalDays - 1));

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

  /// The save that would restore this game.
  SaveData toSave() => SaveData(
    masterSeed: masterSeed,
    tuning: tuning,
    day: _day,
    bets: List<PlayerBet>.of(_history),
  );

  /// Re-applies an already-settled bet from a save.
  ///
  /// Money and scoreboard only: the match it refers to was replayed by the
  /// constructor, so re-running the engine here would play it twice.
  void _replay(PlayerBet bet) {
    _bankroll += bet.profit;
    performance.record(
      stake: bet.stake,
      profit: bet.profit,
      clv: bet.closingLineValue,
    );
    _history.add(bet);
  }

  void _openDay() {
    _fixtures = _builder.cardsFor(
      league: _league,
      day: _day,
      states: _states,
    );
  }

  static MatchOutcome _outcomeFor(MatchResult result, {required bool isHome}) {
    if (result.drawn) {
      return MatchOutcome.draw;
    }
    return result.homeWon == isHome ? MatchOutcome.win : MatchOutcome.loss;
  }
}
