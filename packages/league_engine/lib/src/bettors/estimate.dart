import 'package:league_engine/src/bettors/protocol.dart';
import 'package:league_engine/src/latent/modifiers.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/scoreline/dixon_coles.dart';
import 'package:league_engine/src/scoreline/protocol.dart';

/// A studious player's own probabilities: the book's de-vigged opinion,
/// adjusted for whatever fatigue and form they have managed to observe.
///
/// Shared, because the same reasoning has to serve two situations that look
/// different and are not: pricing a market bet, and deciding whether a friend
/// has offered you a bad price. Both come down to "what do I think this is,
/// against what am I being asked to pay".
///
/// The player is never handed the truth. The match is re-priced twice through
/// the SAME model -- once as the book sees it, once with the state the player
/// believes in -- and only the RATIO between those is applied to the book's
/// opinion.
List<double> studiedEstimate(BettingView view, DixonColesModel model) {
  final bookOpinion = view.market.fairProbabilities;
  final homeFatigue = view.observedHomeFatigue;
  final awayFatigue = view.observedAwayFatigue;
  final homeForm = view.observedHomeForm;
  final awayForm = view.observedAwayForm;

  if (homeFatigue == null &&
      awayFatigue == null &&
      homeForm == null &&
      awayForm == null) {
    return bookOpinion;
  }

  // Re-price the match twice through the SAME model: once as the book sees
  // it (no fatigue) and once with the fatigue the player believes in. The
  // ratio between those is the correction to apply to the book's opinion,
  // so the player is never handed the truth -- only a delta the book missed.
  const modifiers = LatentModifiers();
  final neutral = model.outcomeProbabilities(
    MatchContext(
      home: view.context.home,
      away: view.context.away,
      homeModifiers: const MatchModifiers(),
      awayModifiers: const MatchModifiers(),
      seedPath: view.context.seedPath,
      weather: view.context.weather,
    ),
  );
  final adjusted = model.outcomeProbabilities(
    MatchContext(
      home: view.context.home,
      away: view.context.away,
      homeModifiers: modifiers.project(
        LatentState(fatigue: homeFatigue ?? 0),
      ),
      awayModifiers: modifiers.project(
        LatentState(fatigue: awayFatigue ?? 0),
      ),
      seedPath: view.context.seedPath,
      weather: view.context.weather,
    ),
  );

  final corrected = <double>[
    for (var i = 0; i < 3; i++)
      bookOpinion[i] * (adjusted.asList[i] / neutral.asList[i]),
  ];
  final total = corrected.reduce((a, b) => a + b);
  return <double>[for (final p in corrected) p / total];
}
