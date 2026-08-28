/// Deterministic, headless simulation of a fictional sports league and its
/// bookmaker.
library;

export 'src/engine/match_runner.dart';
export 'src/latent/config.dart';
export 'src/latent/decay.dart';
export 'src/latent/modifiers.dart';
export 'src/latent/shocks.dart';
export 'src/latent/state.dart';
export 'src/league/entities.dart';
export 'src/league/generate.dart';
export 'src/league/name_corpus.dart';
export 'src/league/names.dart';
export 'src/league/schedule.dart';
export 'src/ratings/glicko2_types.dart';
export 'src/ratings/glicko2_update.dart';
export 'src/ratings/glicko2_volatility.dart';
export 'src/rng/mix32.dart';
export 'src/rng/scripted.dart';
export 'src/rng/seeds.dart';
export 'src/rng/source.dart';
export 'src/scoreline/dixon_coles.dart';
export 'src/scoreline/events.dart';
export 'src/scoreline/poisson_params.dart';
export 'src/scoreline/protocol.dart';
