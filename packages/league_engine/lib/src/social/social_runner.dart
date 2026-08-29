import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/flow.dart';
import 'package:league_engine/src/book/odds.dart';
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
import 'package:league_engine/src/social/circle.dart';
import 'package:league_engine/src/social/friend.dart';
import 'package:league_engine/src/social/proposal.dart';

/// Plays a season of PEER bets: no book, no vig, just your mates.
///
/// A separate runner rather than a flag on `SeasonRunner`, for two reasons.
/// The arithmetic is different -- laying somebody's pick is not the same shape
/// as backing a selection -- and keeping it out means the acceptance gate's
/// existing numbers cannot move by accident.
///
/// The `SettledBet`s it produces describe YOUR side: `selection` is the
/// outcome you are AGAINST, `stake` is what you put at risk, and `taken` is
/// the lay price that implies. Read them that way and the ROI arithmetic is
/// the same as everywhere else.
class SocialSeasonRunner {
  /// Creates a runner.
  const SocialSeasonRunner({
    this.model = const DixonColesModel(),
    this.bookmaker = const Bookmaker(),
    this.openingLine = const OpeningLine(),
    this.flow = const MoneyFlow(),
    this.latentConfig = const LatentConfig(),
    this.circle = const FriendCircle(),
    this.circleConfig = const FriendCircleConfig(),
    this.fatigueObservationNoise = 0.12,
    this.midweekFixtureRate = 0.25,
    this.bookLatentAwareness = 0.7,
  });

  /// The scoreline engine.
  final DixonColesModel model;

  /// The book. Present because friends price off the PUBLISHED line, so the
  /// market has to exist even though nobody bets into it here.
  final Bookmaker bookmaker;

  /// How the book's opening estimate is formed.
  final OpeningLine openingLine;

  /// How the line moves before kick-off.
  final MoneyFlow flow;

  /// Latent-layer tunables.
  final LatentConfig latentConfig;

  /// Who is asking, and how they price it.
  final FriendCircle circle;

  /// How many friends, and how varied.
  final FriendCircleConfig circleConfig;

  /// How accurately the player can read fixture congestion.
  final double fatigueObservationNoise;

  /// The chance a club plays an extra midweek match before a matchday.
  final double midweekFixtureRate;

  /// How much of the clubs' hidden state the book manages to price.
  final double bookLatentAwareness;

  /// Runs one season of friend bets and returns what [reviewer] made of it.
  SeasonResult run({
    required int masterSeed,
    required ProposalReviewer reviewer,
    int season = 0,
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
    final friends = generateFriends(
      masterSeed,
      <int>[for (final t in league.teams) t.id],
      circleConfig,
    );

    final states = <int, LatentState>{
      for (final t in league.teams) t.id: const LatentState(),
    };
    final days = <MatchdayResult>[];

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
        final betRng = Mix32Source(deriveSeed(path.child(possession: 3)));
        final view = BettingView(
          market: markets.opening,
          context: ctx,
          observedHomeFatigue: _observe(homeState.fatigue, betRng),
          observedAwayFatigue: _observe(awayState.fatigue, betRng),
          observedHomeForm: _observeSigned(homeState.form, betRng),
          observedAwayForm: _observeSigned(awayState.form, betRng),
        );

        final result = runner.run(ctx);
        for (final terms in circle.proposalsFor(
          ctx: ctx,
          path: path,
          friends: friends,
          market: markets.opening,
        )) {
          final struck = _strike(terms, reviewer, view);
          if (struck != null) {
            settled.add(_settle(struck, result));
          }
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

    return SeasonResult(matchdays: days, bettorName: reviewer.name);
  }

  /// The bet that was actually struck, or null if nobody shook hands.
  static FriendProposal? _strike(
    ProposalTerms terms,
    ProposalReviewer reviewer,
    BettingView view,
  ) {
    final decision = reviewer.review(terms.proposal, view);
    if (decision.accepted) {
      return terms.proposal;
    }
    final counter = decision.counter;
    if (counter == null || !terms.wouldAccept(counter)) {
      return null;
    }
    return terms.proposal.at(counter);
  }

  static SettledBet _settle(FriendProposal struck, MatchResult result) {
    final risked = struck.atRisk;
    return SettledBet(
      bet: Bet(
        selection: struck.selection,
        stake: risked,
        // Your side of it: risk `atRisk` to win their stake.
        taken: Odds(1 + struck.stake / risked),
      ),
      profit: settleProposal(struck, result),
      // There is no closing line on a handshake.
      closingLineValue: 0,
    );
  }

  double _observe(double actual, RandomSource rng) =>
      (actual + rng.normal(0, fatigueObservationNoise)).clamp(0.0, 1.0);

  double _observeSigned(double actual, RandomSource rng) =>
      (actual + rng.normal(0, fatigueObservationNoise)).clamp(-1.0, 1.0);

  static MatchOutcome _outcomeFor(MatchResult result, bool isHome) {
    if (result.drawn) {
      return MatchOutcome.draw;
    }
    return result.homeWon == isHome ? MatchOutcome.win : MatchOutcome.loss;
  }
}
