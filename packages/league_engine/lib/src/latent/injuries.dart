import 'package:league_engine/src/latent/config.dart';
import 'package:league_engine/src/latent/shocks.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';

/// Injuries for both round loops (`SeasonRunner`, the app's `playMatchday`).
class InjuryClock {
  /// Creates a clock.
  const new([this._config = const LatentConfig()]);

  static const int _slot = 18;

  final LatentConfig _config;

  /// The dice for club [clubId]'s injury roll on matchday [day].
  ///
  /// The caller rolls them with `LatentShocks.rollInjury` and hands the
  /// verdict to [afterMatch], so each round loop names the roll itself.
  RandomSource rngFor({required SeedPath day, required int clubId}) =>
      Mix32Source(deriveSeed(day.child(match: clubId, possession: _slot)));

  /// Applies a rolled injury verdict [hurt] to [state], up to the cap.
  LatentState afterMatch(LatentState state, {required bool hurt}) {
    if (!hurt || state.injuredCount >= _config.maxInjured) {
      return state;
    }
    return state.copyWith(
      injuredCount: state.injuredCount + 1,
      injuryDays: state.injuredCount == 0 ? 0 : state.injuryDays,
    );
  }

  /// One matchday of recovery; checked before the week passes.
  LatentState rest(LatentState state) {
    if (state.injuredCount == 0) {
      return state.copyWith(injuryDays: 0);
    }
    final remaining = LatentShocks(_config)
        .recoverInjuries(state, state.injuryDays);
    if (remaining == 0) {
      return state.copyWith(injuredCount: 0, injuryDays: 0);
    }
    final clock = remaining < state.injuredCount ? 0 : state.injuryDays;
    return state.copyWith(
      injuredCount: remaining,
      injuryDays: clock + _config.daysPerMatchday,
    );
  }
}
