import 'package:league_engine/src/book/pricing.dart';

/// One tipster's call on one fixture.
///
/// [believedProbability] is what they actually think, which is NOT shown to
/// the player -- only [confidence] and the words are. That asymmetry is the
/// point: you cannot read somebody's edge off their post, you can only find
/// it by writing down what they said and checking later.
class Tip {
  /// Creates a tip.
  const Tip({
    required this.tipsterId,
    required this.handle,
    required this.selection,
    required this.believedProbability,
    required this.confidence,
    required this.text,
  });

  /// Who said it.
  final int tipsterId;

  /// What they post under.
  final String handle;

  /// What they are on.
  final Selection selection;

  /// The chance they privately give it.
  final double believedProbability;

  /// How loudly they said it, 0..1. Says nothing about whether it is right.
  final double confidence;

  /// The post itself.
  final String text;

  /// How far their opinion sits above the market's own, de-vigged.
  ///
  /// Positive means they think this is a bet. Available to the engine's
  /// bettors; the player has to eyeball the price like everyone else.
  double edgeAgainst(Market market) =>
      believedProbability - market.fairProbabilities[selection.index];

  @override
  String toString() => '$handle: ${selection.name}';
}
