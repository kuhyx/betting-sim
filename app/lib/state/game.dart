import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/day_builder.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/life.dart';
import 'package:betting_sim/state/matchday.dart';
import 'package:betting_sim/state/performance.dart';
import 'package:betting_sim/state/purse.dart';
import 'package:betting_sim/state/records.dart';
import 'package:betting_sim/state/save.dart';
import 'package:betting_sim/state/settler.dart';
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
  /// A save carries no league, no hidden state and no scorelines: the only way
  /// back to matchday N is to play 0 to N-1 again from the same seed. If
  /// replay ever diverged, this is what would notice.
  factory GameState.fromSave(SaveData save) {
    final game = GameState(masterSeed: save.masterSeed, tuning: save.tuning);
    // Rounds only, never the days: the league replays from the seed, and how
    // somebody spent a Tuesday does not.
    for (var i = 0; i < save.day; i++) {
      game._playRound();
    }
    game.life.restore(save.life);
    game.purse.adjust(save.life.lifeMoney);
    save.bets.forEach(game._replay);
    save.peerBets.forEach(game._replayPeer);
    return game;
  }

  /// What every game starts with.
  static const double openingBankroll = 1000;

  /// The save's root seed.
  final int masterSeed;

  /// The balance knobs this game was generated under.
  ///
  /// Immutable: changing a knob changes pricing, so retuning builds a fresh
  /// [GameState] rather than mutating this one.
  final Tuning tuning;

  /// The money, and everything it has done.
  final Purse purse = Purse();

  /// The player's running ROI and CLV against the book.
  Performance get performance => purse.performance;

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
    tipsters: records.tipsters,
    friends: records.friends,
  );

  /// The tipsters, the friends, and the notebooks you keep on both.
  late final Records records = Records(
    masterSeed: masterSeed,
    clubIds: <int>[for (final t in _league.teams) t.id],
  );

  /// Which calendar day each matchday falls on.
  late final SeasonCalendar calendar = SeasonCalendar(
    matchdays: _league.matchdays,
  );

  int _day = 0;
  List<FixtureCard> _fixtures = <FixtureCard>[];
  final Map<int, ({Selection selection, double stake})> _slip =
      <int, ({Selection selection, double stake})>{};
  List<PlayedMatch> _played = <PlayedMatch>[];

  /// Which matchday is showing.
  int get day => _day;

  /// How many matchdays the season has.
  int get totalDays => _league.matchdays;

  /// How the week is going: the clock, the needs, the rent.
  final LifeState life = LifeState();

  /// Today's date. The season runs a round a week; the other six days are
  /// where everything that is not a match happens.
  GameDate get date => life.date;

  /// The player's money.
  double get bankroll => purse.bankroll;

  /// Today's fixtures and prices.
  List<FixtureCard> get fixtures => List.unmodifiable(_fixtures);

  /// Every settled bet, most recent first.
  List<PlayerBet> get history => purse.bets;

  /// Every settled friend bet, most recent first.
  List<PeerBet> get peerHistory => purse.peerBets;

  /// The bets staked but not yet settled.
  Map<int, ({Selection selection, double stake})> get slip =>
      Map.unmodifiable(_slip);

  /// The matches from the last round, for watching back. Already decided by
  /// the time this list exists, which is the point.
  List<PlayedMatch> get played => List.unmodifiable(_played);

  /// Whether there is any more game to play.
  ///
  /// Either the fixtures ran out or you did: an eviction ends a run as surely
  /// as the final whistle, which is the point of the rent existing at all.
  bool get seasonOver => _day >= _league.matchdays || !life.running;

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
  /// Lives one day of the week. Returns whether the round was played.
  ///
  /// The clock. Matches happen on the Saturday you reach rather than on a
  /// button press, so an hour worked is an hour not spent on the feed.
  bool liveDay(List<Activity> plan) {
    final played = _liveOneDay(plan);
    notifyListeners();
    return played;
  }

  /// Gets on with the week however it goes, and plays the round at the end.
  ///
  /// The casual path, and the reason the clock cannot drift out of step with
  /// the fixtures: a round cannot be played without the days in front of it
  /// also happening. Unplanned days are spent the ordinary way.
  void advanceDay() {
    const ordinary = Grafter();
    var played = false;
    while (!seasonOver && !played) {
      played = _liveOneDay(ordinary.planFor(life.date, life.needs));
    }
    notifyListeners();
  }

  /// Buys [item], if it can be afforded.
  void buy(Purchase item) {
    purse.adjust(life.buy(item, purse.bankroll));
    notifyListeners();
  }

  bool _liveOneDay(List<Activity> plan) {
    if (seasonOver) {
      return false;
    }
    final today = life.date;
    purse.adjust(life.live(plan));
    if (today.weekday == LifeState.rentDay) {
      purse.adjust(life.settleRent(purse.bankroll));
    }
    final playing = calendar.matchdayOn(today) == _day;
    if (playing) {
      _playRound();
    }
    if (life.dayOfSeason >= calendar.totalDays) {
      life.finish();
    }
    return playing;
  }

  void _playRound() {
    final round = playMatchday(
      fixtures: _fixtures,
      slip: _slip,
      runner: _runner,
      decay: _decay,
      records: records,
      states: _states,
      league: _league,
    );
    // `Records.settle` has already put the friend bets in the book, so only
    // the money and the history are left to move.
    round.bets.forEach(purse.take);
    round.peerBets.forEach(purse.takePeer);

    _played = round.played;
    _slip.clear();
    records.nextDay();
    _day++;
    _openDay();
  }

  /// Re-applies a settled bet from a save. Money only: the match it refers to
  /// was already replayed by the constructor.
  void _replay(PlayerBet bet) => purse.take(bet);

  /// Re-applies an already-settled friend bet from a save.
  void _replayPeer(PeerBet bet) {
    purse.takePeer(bet);
    records.friendBook.add(bet);
  }

  /// Puts the next round's card up, or nothing if the season ran out.
  void _openDay() => _fixtures = _day >= _league.matchdays
      ? <FixtureCard>[]
      : _builder.cardsFor(league: _league, day: _day, states: _states);
}
