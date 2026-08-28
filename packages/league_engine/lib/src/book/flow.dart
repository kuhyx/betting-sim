import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// Moves a line as money arrives.
///
/// Two kinds of money push in different directions. SHARP money follows the
/// truth, so a line that moves toward the true probability is a signal. PUBLIC
/// money follows reputation and drags the line away from it, which is what
/// creates value on the unfashionable side.
///
/// Reverse line movement -- a line moving AGAINST where the public is betting
/// -- is therefore the clearest tell that sharp money has arrived, and it is a
/// pattern the player can learn to read.
class MoneyFlow {
  /// Creates a flow model.
  const MoneyFlow({
    this.sharpWeight = 0.55,
    this.publicWeight = 0.3,
    this.publicBiasStrength = 0.06,
  });

  /// How strongly the line converges on the truth per round of sharp money.
  final double sharpWeight;

  /// How strongly public money pulls the line toward the popular side.
  final double publicWeight;

  /// How large the public's bias is.
  final double publicBiasStrength;

  /// Advances the book's estimate one round toward its closing value.
  ///
  /// [popular] is the selection the public likes, normally the favourite.
  OutcomeProbs step(
    OutcomeProbs current,
    OutcomeProbs truth,
    Selection popular,
    RandomSource rng,
  ) {
    // Public money leans first, THEN sharp money corrects toward the truth.
    // The order matters: applying the public lean LAST left it uncorrected, so
    // the close sat permanently 1.02pp above truth on the popular side and
    // every bettor -- including a random one -- collected free closing-line
    // value. CLV is zero-sum across a market; a random bettor showing positive
    // CLV means the line is drifting, not moving.
    final leaned = List<double>.of(current.asList);
    leaned[popular.index] +=
        publicBiasStrength * publicWeight * (rng.uniform01() - 0.5);

    final moved = <double>[
      for (var i = 0; i < 3; i++)
        leaned[i] + sharpWeight * (truth.asList[i] - leaned[i]),
    ];

    final total = moved.reduce((a, b) => a + b);
    return OutcomeProbs(
      home: moved[0] / total,
      draw: moved[1] / total,
      away: moved[2] / total,
    );
  }
}
