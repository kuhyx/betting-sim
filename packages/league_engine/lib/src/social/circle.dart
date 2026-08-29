import 'package:league_engine/src/book/odds.dart';
import 'package:league_engine/src/book/opinion.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';
import 'package:league_engine/src/scoreline/protocol.dart';
import 'package:league_engine/src/social/friend.dart';
import 'package:league_engine/src/social/messages.dart';
import 'package:league_engine/src/social/proposal.dart';

/// How friends size and price what they offer.
class ProposalConfig {
  /// Creates the tuning for how proposals are formed.
  const ProposalConfig({this.stake = (low: 5, high: 40)});

  /// What they are willing to put up.
  final ({double low, double high}) stake;
}

/// The people you know, and what they fancy this week.
///
/// A friend's BIAS decides what they want to talk about; it does NOT distort
/// the price they ask for it. That split is load-bearing. If bias moved their
/// estimate too, then laying their standing error would be free money and
/// accepting everything would print -- which is precisely what gate 5a
/// forbids. As built, their price is honest by their own lights and your edge
/// comes only from knowing the fixture better than they do.
class FriendCircle {
  /// Creates a circle.
  const FriendCircle({
    this.model = const DixonColesModel(),
    this.config = const ProposalConfig(),
  });

  /// Used to evaluate the informed view of a fixture.
  final DixonColesModel model;

  /// Stake sizing.
  final ProposalConfig config;

  /// What your friends want on this fixture, if anything.
  ///
  /// Draws from `possession: 31`, disjoint from the book, the match, the
  /// bettor and the feed.
  List<ProposalTerms> proposalsFor({
    required MatchContext ctx,
    required SeedPath path,
    required List<Friend> friends,
    required Market market,
  }) {
    final rng = Mix32Source(deriveSeed(path.child(possession: proposalSlot)));
    final truth = model.outcomeProbabilities(ctx);
    final fair = market.fairProbabilities;
    final published = OutcomeProbs(home: fair[0], draw: fair[1], away: fair[2]);

    final proposals = <ProposalTerms>[];
    for (final friend in friends) {
      // Every friend rolls, in a fixed order, whether or not they speak --
      // so one going quiet cannot shift what the next one says.
      final speaks = rng.uniform01() < friend.chattiness;
      final believed = _believed(friend, truth, published, rng);
      final selection = _wants(friend, ctx, published);
      final stake = _stake(rng);
      final message = writeProposal(
        friend: friend,
        selection: selection,
        home: ctx.home,
        away: ctx.away,
        stake: stake,
        rng: rng,
      );
      if (!speaks) {
        continue;
      }
      // Fair by their own lights: no margin, because a friend is not a book.
      final asked = Odds(1 / believed.asList[selection.index]);
      proposals.add(
        ProposalTerms(
          proposal: FriendProposal(
            friendId: friend.id,
            name: friend.name,
            selection: selection,
            stake: stake,
            odds: asked,
            message: message,
          ),
          floorOdds: Odds(1 + asked.profit * (1 - friend.stubbornness)),
        ),
      );
    }
    return proposals;
  }

  OutcomeProbs _believed(
    Friend friend,
    OutcomeProbs truth,
    OutcomeProbs published,
    RandomSource rng,
  ) {
    final opinion = blendOpinions(truth, published, friend.awareness);
    return perturbLogOdds(opinion, friend.noise, rng);
  }

  Selection _wants(
    Friend friend,
    MatchContext ctx,
    OutcomeProbs published,
  ) {
    switch (friend.bias) {
      case FriendBias.cagey:
        return Selection.draw;
      case FriendBias.chalk:
        return favouriteOf(published);
      case FriendBias.longshot:
        return _longest(published);
      case FriendBias.loyal:
        if (friend.loyalClubId == ctx.home.id) {
          return Selection.home;
        }
        if (friend.loyalClubId == ctx.away.id) {
          return Selection.away;
        }
        // Their club is not playing, so they revert to type: the favourite.
        return favouriteOf(published);
    }
  }

  double _stake(RandomSource rng) {
    final drawn =
        config.stake.low +
        rng.uniform01() * (config.stake.high - config.stake.low);
    return drawn.roundToDouble();
  }

  static Selection _longest(OutcomeProbs probs) {
    var worst = Selection.home;
    for (final s in Selection.values) {
      if (probs.asList[s.index] < probs.asList[worst.index]) {
        worst = s;
      }
    }
    return worst;
  }
}
