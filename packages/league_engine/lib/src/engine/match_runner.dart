import 'package:league_engine/src/latent/config.dart';
import 'package:league_engine/src/latent/modifiers.dart';
import 'package:league_engine/src/latent/shocks.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/narration_config.dart';
import 'package:league_engine/src/scoreline/narrator.dart';
import 'package:league_engine/src/scoreline/protocol.dart';
import 'package:league_engine/src/scoreline/timeline.dart';

/// Runs one match end to end, from its address in the seed tree.
///
/// This is the class that makes the architecture's central promise true: given
/// a [SeedPath] and the state the two clubs were in, a match replays exactly,
/// with no need to simulate the season around it.
class MatchRunner {
  /// Creates a runner.
  const MatchRunner({
    required this.model,
    this.latentConfig = const LatentConfig(),
    this.narrationConfig = const NarrationConfig(),
  });

  /// The scoreline engine. Swappable: any [ScorelineModel] works.
  final ScorelineModel model;

  /// Latent-layer tunables.
  final LatentConfig latentConfig;

  /// Rates for the match report.
  final NarrationConfig narrationConfig;

  /// Builds the context for a match without playing it.
  ///
  /// Separated from [run] because the bookmaker needs to price a match from
  /// this context BEFORE anyone plays it -- and pricing must not consume the
  /// match's randomness.
  ///
  /// The weather and referee draws come from a dedicated `possession: 0`
  /// sub-seed, so they are settled before kick-off and are not disturbed by
  /// how many goals are later scored.
  MatchContext contextFor({
    required Team home,
    required Team away,
    required LatentState homeState,
    required LatentState awayState,
    required SeedPath seedPath,
  }) {
    final preMatch = Mix32Source(deriveSeed(seedPath.child(possession: 0)));
    final shocks = LatentShocks(latentConfig);
    final weather = shocks.rollWeather(preMatch);
    final referee = shocks.rollRefereeBias(preMatch);
    final modifiers = LatentModifiers(latentConfig);

    return MatchContext(
      home: home,
      away: away,
      homeModifiers: modifiers.project(homeState, weather: weather),
      awayModifiers: modifiers.project(awayState, weather: weather),
      seedPath: seedPath,
      weather: weather,
      refereeBias: referee,
    );
  }

  /// Plays the match described by [ctx].
  ///
  /// Draws from a `possession: 1` sub-seed, disjoint from the pre-match draws,
  /// so pricing a match and playing it never share a stream.
  MatchResult run(MatchContext ctx) {
    final rng = Mix32Source(deriveSeed(ctx.seedPath.child(possession: 1)));
    return model.simulate(ctx, rng);
  }

  /// Elaborates [result] into a watchable match report.
  ///
  /// OPT-IN, and separate from [run] on purpose. Narration draws from
  /// its own `NarrationSlot` sub-seeds (4-17), so it cannot disturb the score
  /// -- but it is also
  /// pure cost on the acceptance gate's 200-season batch, which never looks
  /// at a match report. `SeasonRunner` therefore does not call this; the app
  /// does, for the one match the player is actually watching.
  MatchTimeline narrate(MatchContext ctx, MatchResult result) =>
      MatchNarrator(narrationConfig).narrate(ctx, result);
}
