import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// Mixes a fully-informed view of a match with a latent-blind one.
///
/// The construction the whole game balances on. Pricing `truth + noise` would
/// already embed fatigue and form perfectly, leaving nothing to know -- so an
/// opinion that is only PARTIALLY aware has to be built explicitly, out of two
/// separate evaluations of the same fixture.
///
/// [awareness] 1 is the truth, 0 is a fixture read as though both clubs were
/// fresh, neutral and fully fit. The book sits at 0.7. A tipster who sits
/// higher than the book knows something the price does not, and that gap is
/// the only place an edge can come from.
OutcomeProbs blendOpinions(
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
Selection favouriteOf(OutcomeProbs probs) {
  var best = Selection.home;
  for (final s in Selection.values) {
    if (probs.asList[s.index] > probs.asList[best.index]) {
      best = s;
    }
  }
  return best;
}

/// Renormalises [weights] into probabilities, flooring each at [floor].
///
/// The floor is not cosmetic. Noise and bias can push a component negative,
/// and a negative "probability" would produce a price below evens on an
/// outcome that cannot happen. Flooring first, normalising second, keeps
/// every opinion a real distribution however badly it was distorted.
OutcomeProbs normaliseOpinion(List<double> weights, {double floor = 0.01}) {
  final floored = <double>[
    for (final w in weights)
      if (w < floor) floor else w,
  ];
  final total = floored.reduce((a, b) => a + b);
  return OutcomeProbs(
    home: floored[0] / total,
    draw: floored[1] / total,
    away: floored[2] / total,
  );
}
