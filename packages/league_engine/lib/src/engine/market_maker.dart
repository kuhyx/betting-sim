import 'package:league_engine/src/book/flow.dart';
import 'package:league_engine/src/book/opening.dart';
import 'package:league_engine/src/book/opinion.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// The opening and closing markets on one fixture.
class MatchMarkets {
  /// Creates a market pair.
  const MatchMarkets({required this.opening, required this.closing});

  /// The price the player may bet into.
  final Market opening;

  /// Where the line finished, which is what CLV is measured against.
  final Market closing;
}

/// Builds the market a bettor sees, and where that market closes.
///
/// Split out of the season runner because it is a distinct concern with a
/// distinct rule: the book must be FALLIBLE in a specific, bounded way, and
/// that fallibility is the player's whole opportunity.
class MarketMaker {
  /// Creates a market maker.
  const MarketMaker({
    required this.model,
    required this.bookmaker,
    required this.openingLine,
    required this.flow,
    required this.bookLatentAwareness,
  });

  /// The scoreline engine, used to re-price a latent-blind view.
  final DixonColesModel model;

  /// The book.
  final Bookmaker bookmaker;

  /// How the opening estimate is formed.
  final OpeningLine openingLine;

  /// How the line moves before kick-off.
  final MoneyFlow flow;

  /// How much hidden state the book manages to price. See [SeasonRunner].
  final double bookLatentAwareness;

  /// Prices [ctx], returning the opening and closing markets.
  MatchMarkets marketsFor({
    required MatchContext ctx,
    required Team home,
    required Team away,
    required SeedPath path,
  }) {
    final rng = Mix32Source(deriveSeed(path.child(possession: 2)));
    final truth = model.outcomeProbabilities(ctx);

    // The book's blind spot, constructed explicitly: the same fixture with
    // both clubs treated as fresh and neutral. Pricing `truth` plus noise
    // would already embed fatigue and form perfectly, leaving nothing to know
    // -- measured, the skilled bettor's correction then made its estimate
    // WORSE than the book's (4.81pp mean error against 3.84pp) because it was
    // double-counting state the book had already priced.
    final unaware = model.outcomeProbabilities(ctx.latentBlind);
    final blind = blendOpinions(truth, unaware, bookLatentAwareness);

    final deviation = home.rating.deviation + away.rating.deviation;
    var opinion = openingLine.estimate(blind, deviation, rng);
    final opening = bookmaker.price(opinion);

    // The public backs the favourite, whichever side that is. Always choosing
    // home made the drift one-directional and handed every bettor free CLV on
    // that side -- 1.02pp of it, which a random bettor collected too.
    final favourite = favouriteOf(opinion);
    for (var round = 0; round < 3; round++) {
      opinion = flow.step(opinion, blind, favourite, rng);
    }

    return MatchMarkets(opening: opening, closing: bookmaker.price(opinion));
  }
}
