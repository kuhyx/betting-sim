import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/records.dart';
import 'package:betting_sim/state/settler.dart';
import 'package:league_engine/league_engine.dart';

/// What a matchday did.
class MatchdayOutcome {
  /// Creates an outcome.
  const MatchdayOutcome({
    required this.played,
    required this.bets,
    required this.peerBets,
  });

  /// The matches, for watching back.
  final List<PlayedMatch> played;

  /// Bets settled against the book.
  final List<PlayerBet> bets;

  /// Bets settled against friends.
  final List<PeerBet> peerBets;

  /// What the whole round did to the money.
  double get profit =>
      bets.fold<double>(0, (sum, b) => sum + b.profit) +
      peerBets.fold<double>(0, (sum, b) => sum + b.profit);
}

/// Plays a round: every match, every bet, every notebook.
///
/// Split out of `GameState` because it is the one place where four separate
/// things happen to the same fixture in a fixed order -- the match, the book
/// bet, the friend bets, and the hidden state moving on -- and reading that
/// order in one function is worth more than having it inline.
///
/// Mutates [states] and [records] deliberately: the clubs' hidden state and
/// your notebooks carry over, and copying them would only hide that.
MatchdayOutcome playMatchday({
  required List<FixtureCard> fixtures,
  required Map<int, ({Selection selection, double stake})> slip,
  required MatchRunner runner,
  required LatentDecay decay,
  required Records records,
  required Map<int, LatentState> states,
  required League league,
}) {
  final played = <PlayedMatch>[];
  final bets = <PlayerBet>[];
  final peerBets = <PeerBet>[];

  for (final card in fixtures) {
    final result = runner.run(card.context);
    played.add(PlayedMatch.of(card, result));
    peerBets.addAll(records.settle(card, result));

    final staked = slip[card.index];
    if (staked != null) {
      bets.add(
        settleCard(
          card: card,
          selection: staked.selection,
          stake: staked.stake,
          result: result,
        ),
      );
    }

    states[card.home.id] = decay.afterMatch(
      states[card.home.id]!,
      _outcomeFor(result, isHome: true),
    );
    states[card.away.id] = decay.afterMatch(
      states[card.away.id]!,
      _outcomeFor(result, isHome: false),
    );
  }

  for (final team in league.teams) {
    states[team.id] = decay.rest(states[team.id]!);
  }

  return MatchdayOutcome(played: played, bets: bets, peerBets: peerBets);
}

MatchOutcome _outcomeFor(MatchResult result, {required bool isHome}) {
  if (result.drawn) {
    return MatchOutcome.draw;
  }
  return result.homeWon == isHome ? MatchOutcome.win : MatchOutcome.loss;
}
