import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/odds.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// A bet somebody has offered you.
///
/// THEY back [selection] for [stake] at [odds]. You are the one laying it: if
/// their pick comes in you owe them `stake * (odds - 1)`, and if it does not
/// you keep their [stake].
///
/// That asymmetry is why a friend bet is not a smaller bookmaker. There is no
/// margin in it -- the price is what they honestly think is fair -- so the
/// only reason to take one is that you think they are wrong.
class FriendProposal {
  /// Creates a proposal.
  const FriendProposal({
    required this.friendId,
    required this.name,
    required this.selection,
    required this.stake,
    required this.odds,
    required this.message,
  });

  /// Who is asking.
  final int friendId;

  /// What you call them.
  final String name;

  /// What THEY are backing.
  final Selection selection;

  /// What they are putting up.
  final double stake;

  /// The price they want.
  final Odds odds;

  /// What they said.
  final String message;

  /// What you risk by taking this on.
  double get atRisk => stake * odds.profit;

  /// The same proposal struck at [counter] instead.
  FriendProposal at(Odds counter) => FriendProposal(
    friendId: friendId,
    name: name,
    selection: selection,
    stake: stake,
    odds: counter,
    message: message,
  );

  @override
  String toString() =>
      '$name: ${selection.name} @ ${odds.format(OddsFormat.decimal)} '
      'for $stake';
}

/// A proposal, plus the thing about it you are not allowed to see.
///
/// Split from [FriendProposal] so that being unable to read somebody's
/// walk-away price is STRUCTURAL rather than a matter of good manners. A
/// reviewer is handed the proposal; only the arbiter running the season -- or
/// the game itself -- holds the terms. A control that could peek at
/// [floorOdds] would make gate 5 measure nothing.
class ProposalTerms {
  /// Creates terms.
  const ProposalTerms({required this.proposal, required this.floorOdds});

  /// What was offered.
  final FriendProposal proposal;

  /// The worst price they would still shake hands on.
  ///
  /// Countering below it costs you the bet, which is what makes a counter a
  /// decision rather than a free reroll.
  final Odds floorOdds;

  /// Whether [counter] is a price they would accept.
  bool wouldAccept(Odds counter) => counter.decimal >= floorOdds.decimal;
}

/// What you did about a proposal.
enum ProposalOutcome {
  /// Took it as offered.
  accepted,

  /// Turned it down.
  rejected,

  /// Countered, and they shook on it.
  countered,

  /// Countered, and they walked.
  walked,
}

/// Your answer to a proposal.
///
/// A separate protocol from `Bettor` on purpose. `Bettor.betsFor` GENERATES
/// bets against a market; a proposal is a bet you are OFFERED, and the moves
/// available are different ones. Reusing the market view is right; reusing
/// the action shape is not.
class ProposalDecision {
  /// Take it as offered.
  const ProposalDecision.accept() : counter = null, accepted = true;

  /// Turn it down.
  const ProposalDecision.reject() : counter = null, accepted = false;

  /// Offer them [counter] instead. They may walk.
  const ProposalDecision.counterAt(Odds this.counter) : accepted = false;

  /// Whether the offer was taken as it stood.
  final bool accepted;

  /// The price offered back, if any.
  final Odds? counter;
}

/// Someone who decides what to do about the bets their friends offer them.
abstract interface class ProposalReviewer {
  /// How this reviewer is labelled in the acceptance report.
  String get name;

  /// What to do about [proposal], given what you can see of the fixture.
  ProposalDecision review(FriendProposal proposal, BettingView view);
}

/// What laying [proposal] at its stated price returned.
///
/// Positive when their pick loses, because you kept their stake.
double settleProposal(FriendProposal proposal, MatchResult result) {
  final theirsWon = switch (proposal.selection) {
    Selection.home => result.homeWon,
    Selection.draw => result.drawn,
    Selection.away => !result.homeWon && !result.drawn,
  };
  return theirsWon ? -proposal.atRisk : proposal.stake;
}
