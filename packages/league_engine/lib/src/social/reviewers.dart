import 'package:league_engine/src/bettors/estimate.dart';
import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/book/odds.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';
import 'package:league_engine/src/social/proposal.dart';

/// Says yes to everything.
///
/// The control for the friends layer, in the same way `RandomBettor` is the
/// control for the book. A friend's price carries no margin, so this is very
/// nearly a coin flip -- and gate 5a asserts it stays one. If saying yes to
/// everything printed money, choosing would not be a skill.
class AcceptAllReviewer implements ProposalReviewer {
  /// Creates an indiscriminate reviewer.
  const AcceptAllReviewer();

  @override
  String get name => 'accept-all';

  @override
  ProposalDecision review(FriendProposal proposal, BettingView view) =>
      const ProposalDecision.accept();
}

/// Turns down the bets that are wrong for you, and haggles over the rest.
///
/// Uses exactly the reasoning `SkilledBettor` uses on a market: the book's
/// de-vigged opinion, corrected for the fatigue and form it can observe. What
/// changes is the arithmetic at the end. Laying somebody's pick pays their
/// stake when it loses and costs `stake * (odds - 1)` when it wins, so the
/// value per unit staked is `1 - p * odds`, and it FALLS as the price rises.
class ShrewdReviewer implements ProposalReviewer {
  /// Creates a shrewd reviewer.
  const ShrewdReviewer({
    this.edgeThreshold = 0.02,
    this.counterAtEdge = 0.06,
    this.model = const DixonColesModel(),
  });

  /// The least value worth shaking hands on.
  final double edgeThreshold;

  /// The value a counter-offer aims for.
  ///
  /// Higher than [edgeThreshold] on purpose: there is no point countering to
  /// a price you would only just have accepted, and asking for a bit more is
  /// free -- the worst case is that they walk and you are back where you were.
  final double counterAtEdge;

  /// Used to re-price the fixture, never to read the truth.
  final DixonColesModel model;

  @override
  String get name => 'shrewd';

  @override
  ProposalDecision review(FriendProposal proposal, BettingView view) {
    final p = studiedEstimate(view, model)[proposal.selection.index];
    if (1 - p * proposal.odds.decimal > edgeThreshold) {
      return const ProposalDecision.accept();
    }

    // What price WOULD be worth taking? Solve 1 - p*O = counterAtEdge.
    final wanted = (1 - counterAtEdge) / p;
    if (wanted <= 1.01) {
      // They would have to be paying you to take it on. Nothing to say.
      return const ProposalDecision.reject();
    }
    if (wanted >= proposal.odds.decimal) {
      // Their price is already better than the one we would ask for, and we
      // still did not want it. Countering upward would only make it worse.
      return const ProposalDecision.reject();
    }
    return ProposalDecision.counterAt(Odds(wanted));
  }
}
