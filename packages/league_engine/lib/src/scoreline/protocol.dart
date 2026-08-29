import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/events.dart';

/// Win/draw/loss probabilities for a match. Always sums to 1.
class OutcomeProbs {
  /// Creates a probability triple.
  const OutcomeProbs({
    required this.home,
    required this.draw,
    required this.away,
  });

  /// Probability the home side wins.
  final double home;

  /// Probability of a draw.
  final double draw;

  /// Probability the away side wins.
  final double away;

  /// The three outcomes in a fixed order, for pricing loops.
  List<double> get asList => <double>[home, draw, away];

  @override
  String toString() =>
      'OutcomeProbs(${home.toStringAsFixed(3)}/'
      '${draw.toStringAsFixed(3)}/${away.toStringAsFixed(3)})';
}

/// Everything a scoreline model needs to play one match.
class MatchContext {
  /// Creates a context.
  const MatchContext({
    required this.home,
    required this.away,
    required this.homeModifiers,
    required this.awayModifiers,
    required this.seedPath,
    this.weather = Weather.clear,
    this.refereeBias = 1,
  });

  /// The home club.
  final Team home;

  /// The away club.
  final Team away;

  /// The home club's hidden-state effects.
  final MatchModifiers homeModifiers;

  /// The away club's hidden-state effects.
  final MatchModifiers awayModifiers;

  /// This match's address in the seed tree. Replaying the match means
  /// rebuilding a source from here -- nothing else is needed.
  final SeedPath seedPath;

  /// Conditions on the day.
  final Weather weather;

  /// The referee's leaning, as a multiplier on the home scoring rate.
  final double refereeBias;

  /// The same fixture read as though both clubs were fresh, neutral and fully
  /// fit -- no fatigue, no morale, no form, nobody injured.
  ///
  /// The latent-BLIND view, constructed explicitly rather than approximated as
  /// "the truth plus noise", because truth-plus-noise already embeds fatigue
  /// and form perfectly and so leaves nothing to know. Both the bookmaker and
  /// the tipsters are built by blending this against the informed view, which
  /// is what makes partial knowledge modellable at all.
  ///
  /// Weather and the referee carry over: they are PUBLISHED, so nobody is
  /// blind to them.
  MatchContext get latentBlind => MatchContext(
    home: home,
    away: away,
    homeModifiers: const MatchModifiers(),
    awayModifiers: const MatchModifiers(),
    seedPath: seedPath,
    weather: weather,
    refereeBias: refereeBias,
  );
}

/// The outcome of one played match.
class MatchResult {
  /// Creates a result.
  const MatchResult({
    required this.homeScore,
    required this.awayScore,
    required this.events,
  });

  /// Goals scored by the home side.
  final int homeScore;

  /// Goals scored by the away side.
  final int awayScore;

  /// Everything that happened, in minute order. This is the save delta.
  final List<MatchEvent> events;

  /// Whether the home side won.
  bool get homeWon => homeScore > awayScore;

  /// Whether the match was drawn.
  bool get drawn => homeScore == awayScore;

  @override
  String toString() => 'MatchResult($homeScore-$awayScore)';
}

/// Any engine that can price and play a match.
///
/// The two methods are deliberately split. [outcomeProbabilities] is PURE and
/// consumes no randomness, because the bookmaker prices from it: if pricing
/// drew from the match's own RNG, the act of quoting odds would perturb the
/// scoreline and replay would break.
///
/// A possession-based engine for a second sport satisfies the same interface
/// by Monte-Carlo-ing its own probabilities from a separate sub-seed.
abstract interface class ScorelineModel {
  /// True outcome probabilities. No RNG.
  OutcomeProbs outcomeProbabilities(MatchContext ctx);

  /// Plays the match. ALL randomness arrives via [rng].
  MatchResult simulate(MatchContext ctx, RandomSource rng);
}
