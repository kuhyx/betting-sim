import 'package:league_engine/src/book/opinion.dart';
import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/media/post_writer.dart';
import 'package:league_engine/src/media/tip.dart';
import 'package:league_engine/src/media/tipster.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// How hard a tipster's standing lean pulls their opinion.
class TipConfig {
  /// Creates the tuning for how tips are formed.
  const TipConfig({this.lean = 0.18, this.panelNoise = 0.022});

  /// The multiplicative tilt a [TipsterAngle] applies.
  ///
  /// Big enough to be learnable from a season of records, small enough that a
  /// sharp tipster with a lean is still worth reading -- which is what stops
  /// "has a bias" from collapsing into "is useless".
  final double lean;

  /// The error the WHOLE PANEL shares on a fixture, drawn once.
  ///
  /// Load-bearing, and the fix for a measured exploit. With independent errors
  /// only, averaging twelve opinions cancels the noise and leaves the truth,
  /// so following the consensus returned +12.8% -- free money, and the feed
  /// stopped being a thing to get good at. Real pundits all read the same
  /// stories and arrive at the same wrong idea together; correlated error does
  /// not average away, so the crowd stays beatable-by-nobody.
  final double panelNoise;
}

/// Turns a fixture into a page of opinions about it.
///
/// Every tip is generated from the seed tree, so the internet in this game is
/// as replayable as the league is. There is no network call anywhere: the
/// sport, the clubs, the money and the people arguing about them are all
/// invented.
class TipsterDesk {
  /// Creates a desk.
  const TipsterDesk({
    this.model = const DixonColesModel(),
    this.config = const TipConfig(),
  });

  /// Used to evaluate the informed and latent-blind views of a fixture.
  final DixonColesModel model;

  /// How strongly angles bite.
  final TipConfig config;

  /// What the panel is saying about this fixture.
  ///
  /// Draws from `possession: 21`, disjoint from the book, the match and the
  /// bettor, so adding the feed to a save cannot move a single price or a
  /// single scoreline.
  List<Tip> tipsFor({
    required MatchContext ctx,
    required SeedPath path,
    required List<Tipster> tipsters,
    required Market market,
  }) {
    final rng = Mix32Source(deriveSeed(path.child(possession: tipSlot)));
    final truth = model.outcomeProbabilities(ctx);
    final fair = market.fairProbabilities;
    final published = OutcomeProbs(home: fair[0], draw: fair[1], away: fair[2]);
    final favourite = favouriteOf(published);

    // Drawn ONCE, before anybody speaks: the story everybody has read.
    final narrative = <double>[
      for (var i = 0; i < 3; i++) rng.normal(0, config.panelNoise),
    ];

    return <Tip>[
      for (final tipster in tipsters)
        _tipFrom(
          tipster: tipster,
          truth: truth,
          published: published,
          narrative: narrative,
          fair: fair,
          favourite: favourite,
          home: ctx.home,
          away: ctx.away,
          weather: ctx.weather,
          rng: rng,
        ),
    ];
  }

  Tip _tipFrom({
    required Tipster tipster,
    required OutcomeProbs truth,
    required OutcomeProbs published,
    required List<double> narrative,
    required List<double> fair,
    required Selection favourite,
    required Team home,
    required Team away,
    required Weather weather,
    required RandomSource rng,
  }) {
    // Anchored on the PUBLISHED PRICE, not on a clean model evaluation.
    // Awareness is therefore "how far they move from the odds toward the
    // truth": at 0 a tipster is reading the market back to you and cannot
    // beat it by construction, and at a negative value they are worse than
    // the price. Anchoring on the model's own latent-blind view instead
    // handed even a blind tipster the book's pricing noise as an edge --
    // measured, a follower of the WORST tipster on the panel made +7.3%.
    final opinion = blendOpinions(truth, published, tipster.awareness);
    final weights = <double>[
      for (var i = 0; i < 3; i++)
        opinion.asList[i] + narrative[i] + rng.normal(0, tipster.noise),
    ];
    _applyAngle(weights, tipster.angle, favourite);
    final believed = normaliseOpinion(weights);

    // They tip whatever they think is most underpriced, which is what makes a
    // biased tipster READABLE: the lean shows up as a standing preference in
    // the record, not as noise.
    final selection = _bestValue(believed, fair);
    return Tip(
      tipsterId: tipster.id,
      handle: tipster.handle,
      selection: selection,
      believedProbability: believed.asList[selection.index],
      confidence: tipster.confidence,
      text: writePost(
        tipster: tipster,
        selection: selection,
        home: home,
        away: away,
        weather: weather,
        rng: rng,
      ),
    );
  }

  void _applyAngle(
    List<double> weights,
    TipsterAngle angle,
    Selection favourite,
  ) {
    switch (angle) {
      case TipsterAngle.straight:
        return;
      case TipsterAngle.homer:
        weights[Selection.home.index] *= 1 + config.lean;
      case TipsterAngle.favourite:
        weights[favourite.index] *= 1 + config.lean;
      case TipsterAngle.contrarian:
        weights[favourite.index] *= 1 - config.lean;
    }
  }

  static Selection _bestValue(OutcomeProbs believed, List<double> fair) {
    var best = Selection.home;
    var bestEdge = believed.asList[0] - fair[0];
    for (final s in Selection.values) {
      final edge = believed.asList[s.index] - fair[s.index];
      if (edge > bestEdge) {
        best = s;
        bestEdge = edge;
      }
    }
    return best;
  }
}
