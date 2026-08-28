import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/clv.dart';
import 'package:league_engine/src/book/flow.dart';
import 'package:league_engine/src/book/opening.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/engine/market_maker.dart';
import 'package:league_engine/src/engine/match_runner.dart';
import 'package:league_engine/src/engine/results.dart';
import 'package:league_engine/src/latent/config.dart';
import 'package:league_engine/src/latent/decay.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/league/generate.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// Plays a whole season, pricing every match and letting a bettor bet it.
class SeasonRunner {
  /// Creates a season runner.
  const SeasonRunner({
    this.model = const DixonColesModel(),
    this.bookmaker = const Bookmaker(),
    this.openingLine = const OpeningLine(),
    this.flow = const MoneyFlow(),
    this.latentConfig = const LatentConfig(),
    this.fatigueObservationNoise = 0.12,
    this.midweekFixtureRate = 0.25,
    this.bookLatentAwareness = 0.7,
  });

  /// The scoreline engine.
  final DixonColesModel model;

  /// The book.
  final Bookmaker bookmaker;

  /// How the book's opening estimate is formed.
  final OpeningLine openingLine;

  /// How the line moves before kick-off.
  final MoneyFlow flow;

  /// Latent-layer tunables.
  final LatentConfig latentConfig;

  /// How accurately the player can read fixture congestion.
  ///
  /// Not zero: the player's information is good, not perfect. Raising this
  /// erodes the edge, which is the honest way to tune difficulty.
  final double fatigueObservationNoise;

  /// How much of the clubs' hidden state the book manages to price.
  ///
  /// The load-bearing balance knob for the whole gate. At 1.0 the book prices
  /// latent state perfectly and there is nothing to know, so a studious player
  /// cannot win. At 0.0 the book ignores it entirely and the market is so soft
  /// that even a RANDOM bettor turns a profit -- which breaks gate 3 and means
  /// the house edge has stopped existing. Both extremes were measured. The
  /// truth in between is a book that is mostly right and occasionally behind
  /// the news, which is what real books are.
  ///
  /// Measured over 80 seasons per setting (random / skilled / oracle ROI):
  ///   1.00  -4.12%  -4.54%  +22.80%   nothing to know
  ///   0.90  -4.17%  -2.15%  +22.70%   edge too thin to clear the vig
  ///   0.80  -4.16%  +0.44%  +22.78%   skill just beats the margin
  ///   0.70  -4.07%  +3.21%  +23.03%   comfortable
  ///   0.50  -3.69%  +9.47%  +24.86%   too soft
  /// 0.7 is chosen on the PER-SEASON mean, not the pooled figure. Kelly
  /// staking compounds, so a winning season stakes up to 4.6x a losing one and
  /// pooled ROI silently overweights the good ones: at 0.8 the pooled figure
  /// read +0.79% while the median season was -2.1%. The mean of per-season
  /// ROIs is the honest statistic and the one the gate asserts.
  ///
  /// The random bettor stays near -4.76% at every setting, which is the check
  /// that the house edge survives whatever this is tuned to.
  final double bookLatentAwareness;

  /// The chance a club plays an extra midweek match before a matchday.
  ///
  /// Without this the league is perfectly symmetric -- 20 clubs, 10 matches a
  /// day, everyone plays every day -- so fatigue is IDENTICAL for every club
  /// and carries no information at all. Measured: the skilled bettor's CLV was
  /// +0.34% with a 45.5% beat rate, which is no edge. Cup runs and midweek
  /// rounds are what create congestion asymmetry in a real season, and they
  /// are what makes studying the fixture list worth anything.
  final double midweekFixtureRate;

  /// Runs one season and returns what [bettor] made of it.
  SeasonResult run({
    required int masterSeed,
    required Bettor bettor,
    int season = 0,
    double bankroll = 1000,
    LeagueConfig leagueConfig = const LeagueConfig(),
  }) {
    final league = generateLeague(masterSeed, leagueConfig);
    final runner = MatchRunner(model: model, latentConfig: latentConfig);
    final decay = LatentDecay(latentConfig);
    final maker = MarketMaker(
      model: model,
      bookmaker: bookmaker,
      openingLine: openingLine,
      flow: flow,
      bookLatentAwareness: bookLatentAwareness,
    );
    const clv = ClvCalculator();

    final states = <int, LatentState>{
      for (final t in league.teams) t.id: const LatentState(),
    };
    final days = <MatchdayResult>[];
    var purse = bankroll;

    for (var day = 0; day < league.matchdays; day++) {
      final settled = <SettledBet>[];

      for (final (index, fixture) in league.fixturesOn(day).indexed) {
        final path = SeedPath(
          master: masterSeed,
          season: season,
          day: day,
          match: index,
        );
        final home = league.teamById(fixture.homeId);
        final away = league.teamById(fixture.awayId);
        final homeState = states[home.id]!;
        final awayState = states[away.id]!;

        final ctx = runner.contextFor(
          home: home,
          away: away,
          homeState: homeState,
          awayState: awayState,
          seedPath: path,
        );

        final markets = maker.marketsFor(
          ctx: ctx,
          home: home,
          away: away,
          path: path,
        );

        // The player bets the opening line, then the market sharpens.
        final betRng = Mix32Source(deriveSeed(path.child(possession: 3)));
        final bets = bettor.betsFor(
          BettingView(
            market: markets.opening,
            context: ctx,
            observedHomeFatigue: _observe(homeState.fatigue, betRng),
            observedAwayFatigue: _observe(awayState.fatigue, betRng),
            observedHomeForm: _observeSigned(homeState.form, betRng),
            observedAwayForm: _observeSigned(awayState.form, betRng),
          ),
          purse,
          betRng,
        );

        final result = runner.run(ctx);
        for (final bet in bets) {
          final profit = settle(bet, result);
          purse += profit;
          settled.add(
            SettledBet(
              bet: bet,
              profit: profit,
              closingLineValue: clv.forBet(
                selection: bet.selection,
                taken: bet.taken,
                closing: markets.closing,
              ),
            ),
          );
        }

        states[home.id] = decay.afterMatch(
          homeState,
          _outcomeFor(result, true),
        );
        states[away.id] = decay.afterMatch(
          awayState,
          _outcomeFor(result, false),
        );
      }

      // Midweek fixtures: some clubs play again before the next matchday.
      // Drawn from a day-level sub-seed so the schedule is reproducible and
      // -- crucially -- knowable in advance by a player who studies it.
      final congestion = Mix32Source(
        deriveSeed(
          SeedPath(master: masterSeed, season: season, day: day, match: 9999),
        ),
      );
      for (final team in league.teams) {
        var next = decay.rest(states[team.id]!);
        if (congestion.uniform01() < midweekFixtureRate) {
          next = decay.afterMatch(next, MatchOutcome.draw);
        }
        states[team.id] = next;
      }
      days.add(MatchdayResult(day: day, bets: settled));
    }

    return SeasonResult(matchdays: days, bettorName: bettor.name);
  }

  /// The player's noisy reading of a club's tiredness.
  double _observe(double actual, RandomSource rng) {
    final observed = actual + rng.normal(0, fatigueObservationNoise);
    return observed.clamp(0.0, 1.0);
  }

  /// The player's noisy reading of a signed latent value such as form.
  double _observeSigned(double actual, RandomSource rng) {
    final observed = actual + rng.normal(0, fatigueObservationNoise);
    return observed.clamp(-1.0, 1.0);
  }

  static MatchOutcome _outcomeFor(MatchResult result, bool isHome) {
    if (result.drawn) {
      return MatchOutcome.draw;
    }
    final homeWon = result.homeWon;
    return homeWon == isHome ? MatchOutcome.win : MatchOutcome.loss;
  }
}
