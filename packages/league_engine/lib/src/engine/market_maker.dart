import 'package:league_engine/src/book/flow.dart';
import 'package:league_engine/src/book/opening.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/latent/state.dart';
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
    final unaware = model.outcomeProbabilities(
      MatchContext(
        home: home,
        away: away,
        homeModifiers: const MatchModifiers(),
        awayModifiers: const MatchModifiers(),
        seedPath: path,
        weather: ctx.weather,
        refereeBias: ctx.refereeBias,
      ),
    );
    final blind = _blend(truth, unaware, bookLatentAwareness);

    final deviation = home.rating.deviation + away.rating.deviation;
    var opinion = openingLine.estimate(blind, deviation, rng);
    final opening = bookmaker.price(opinion);

    // The public backs the favourite, whichever side that is. Always choosing
    // home made the drift one-directional and handed every bettor free CLV on
    // that side -- 1.02pp of it, which a random bettor collected too.
    final favourite = _favourite(opinion);
    for (var round = 0; round < 3; round++) {
      opinion = flow.step(opinion, blind, favourite, rng);
    }

    return MatchMarkets(opening: opening, closing: bookmaker.price(opinion));
  }

  /// Mixes the fully-informed and latent-blind views by [awareness].
  static OutcomeProbs _blend(
    OutcomeProbs informed,
    OutcomeProbs unaware,
    double awareness,
  ) {
    final mixed = <double>[
      for (var i = 0; i < 3; i++)
        awareness * informed.asList[i] + (1 - awareness) * unaware.asList[i],
    ];
    final total = mixed.reduce((a, b) => a + b);
    return OutcomeProbs(
      home: mixed[0] / total,
      draw: mixed[1] / total,
      away: mixed[2] / total,
    );
  }

  /// The shortest-priced selection: what the public piles onto.
  static Selection _favourite(OutcomeProbs probs) {
    var best = Selection.home;
    for (final s in Selection.values) {
      if (probs.asList[s.index] > probs.asList[best.index]) {
        best = s;
      }
    }
    return best;
  }
}
