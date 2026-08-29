import 'dart:math' as math;

import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/source.dart';
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

/// Perturbs [base] by [sigma] in LOG-ODDS space.
///
/// Not additive noise on the probabilities, and the difference is not
/// cosmetic. Adding 0.06 to a 0.50 chance is a nudge; adding it to a 0.08
/// chance nearly doubles it. That asymmetry matters enormously when somebody
/// is LAYING the result rather than backing it, because a long price is where
/// the layer has the most money at risk -- measured, additive noise made
/// accepting every friend's bet a 2.7% bleed for that reason alone, which is
/// not a house edge so much as a modelling artifact.
///
/// Log-odds noise is scale-free: it moves a 0.08 chance and a 0.5 chance by
/// the same proportional amount. One draw per outcome, then renormalise.
OutcomeProbs perturbLogOdds(
  OutcomeProbs base,
  double sigma,
  RandomSource rng,
) {
  final moved = <double>[
    for (final p in base.asList)
      _sigmoid(math.log(p / (1 - p)) + rng.normal(0, sigma)),
  ];
  return normaliseOpinion(moved);
}

double _sigmoid(double x) => 1 / (1 + math.exp(-x));
