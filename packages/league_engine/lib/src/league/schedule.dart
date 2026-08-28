import 'package:league_engine/src/league/entities.dart';

/// Builds a double round-robin fixture list: every club plays every other
/// club twice, once at home and once away.
///
/// Uses the circle method: fix one club and rotate the rest. With an odd
/// number of clubs a bye is inserted, so those clubs sit out one day per
/// round rather than the schedule being rejected.
List<Fixture> buildSchedule(List<int> teamIds) {
  if (teamIds.length < 2) {
    return const <Fixture>[];
  }

  const bye = -1;
  final ids = List<int>.of(teamIds);
  if (ids.length.isOdd) {
    ids.add(bye);
  }

  final half = ids.length ~/ 2;
  final rotating = List<int>.of(ids.skip(1));
  final fixtures = <Fixture>[];
  final roundCount = ids.length - 1;

  for (var round = 0; round < roundCount; round++) {
    final day = <Fixture>[];
    final order = <int>[ids.first, ...rotating];

    for (var i = 0; i < half; i++) {
      final a = order[i];
      final b = order[order.length - 1 - i];
      if (a == bye || b == bye) {
        continue;
      }
      // Alternate home and away by round so no club is stuck with a lopsided
      // share of home matches in the first half of the season.
      final homeFirst = round.isEven == (i == 0);
      day.add(
        Fixture(
          day: round,
          homeId: homeFirst ? a : b,
          awayId: homeFirst ? b : a,
        ),
      );
    }

    fixtures.addAll(day);
    // Rotate all but the fixed first entry.
    rotating.insert(0, rotating.removeLast());
  }

  // Second half: the same pairings with home and away swapped.
  final firstHalf = List<Fixture>.of(fixtures);
  for (final f in firstHalf) {
    fixtures.add(
      Fixture(
        day: f.day + roundCount,
        homeId: f.awayId,
        awayId: f.homeId,
      ),
    );
  }

  return fixtures;
}
