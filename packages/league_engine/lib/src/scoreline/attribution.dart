import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/scoreline/events.dart';
import 'package:league_engine/src/scoreline/lineup.dart';
import 'package:league_engine/src/scoreline/narration_config.dart';

/// Attaches a scorer to each goal.
///
/// The goals themselves -- how many, and at what minute -- are untouched:
/// they were sampled by the scoreline model from the same grid the book
/// priced. Only the name is new, so `GoalEvent.playerId`, nullable since the
/// type was written and null in every match until now, finally carries one.
///
/// One draw per goal, weighted by attacking ability, in match order.
List<GoalEvent> attributeGoals({
  required List<GoalEvent> goals,
  required TeamSheet homeSheet,
  required TeamSheet awaySheet,
  required RandomSource rng,
}) {
  return <GoalEvent>[
    for (final goal in goals)
      GoalEvent(
        minute: goal.minute,
        byHome: goal.byHome,
        playerId: pickWeighted(
          goal.byHome ? homeSheet.starting : awaySheet.starting,
          (p) => p.attack,
          rng,
        )?.id,
      ),
  ];
}

/// Turns a side's card counts into events with names and minutes on them.
///
/// Weighted by DEFENCE: the players doing the tackling are the players
/// collecting the bookings. Reds are drawn before yellows so a config that
/// forces dismissals reaches that branch without hunting for a seed.
///
/// Two draws per card: who, then when. A side with nobody available gets no
/// cards rather than a crash -- a squad can legally be wiped out.
List<MatchEvent> attributeCards({
  required bool homeSide,
  required int yellows,
  required int reds,
  required TeamSheet sheet,
  required RandomSource rng,
}) {
  final events = <MatchEvent>[];
  for (var i = 0; i < reds + yellows; i++) {
    final player = pickWeighted(sheet.starting, (p) => p.defence, rng);
    if (player == null) {
      continue;
    }
    final minute = rng.randint(1, 90);
    events.add(
      i < reds
          ? RedCardEvent(
              minute: minute,
              homeSide: homeSide,
              playerId: player.id,
            )
          : YellowCardEvent(
              minute: minute,
              homeSide: homeSide,
              playerId: player.id,
            ),
    );
  }
  return events;
}

/// Picks who got hurt, and when.
///
/// Weighted by the INVERSE of stamina, as a subtraction from
/// [NarrationConfig.staminaCeiling] rather than a division, so there is no
/// divide-by-zero case and therefore no branch guarding one.
InjuryEvent? attributeInjury({
  required bool homeSide,
  required TeamSheet sheet,
  required NarrationConfig config,
  required RandomSource rng,
}) {
  final player = pickWeighted(
    sheet.starting,
    (p) => config.staminaCeiling - p.stamina,
    rng,
  );
  if (player == null) {
    return null;
  }
  return InjuryEvent(
    minute: rng.randint(1, 90),
    homeSide: homeSide,
    playerId: player.id,
  );
}

/// Orders [events] as they happened.
///
/// The index tie-break is required, not tidy: `List.sort` is not documented
/// as stable in Dart, so two events in the same minute could order one way on
/// the VM and the other in JavaScript, which
/// `scripts/check_rng_parity.sh` forbids.
List<MatchEvent> inMatchOrder(List<MatchEvent> events) {
  final indexed =
      <({MatchEvent event, int order})>[
        for (final (i, e) in events.indexed) (event: e, order: i),
      ]..sort((a, b) {
        final byMinute = a.event.minute.compareTo(b.event.minute);
        return byMinute != 0 ? byMinute : a.order.compareTo(b.order);
      });
  return <MatchEvent>[for (final e in indexed) e.event];
}
