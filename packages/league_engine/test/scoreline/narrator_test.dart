import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

import 'narrator_support.dart';

const _narrator = MatchNarrator();

void main() {
  final played = result();

  group('MatchNarrator', () {
    test('replays exactly from the same address', () {
      // The whole save format rests on this: a match report is regenerated
      // from its seed path, never stored.
      final once = _narrator.narrate(context(), played);
      final twice = _narrator.narrate(context(), played);

      expect(twice.home.toString(), once.home.toString());
      expect(twice.away.toString(), once.away.toString());
      expect(
        twice.events.map((e) => e.toString()),
        once.events.map((e) => e.toString()),
      );
    });

    test('reports the score it was given, and never another', () {
      final timeline = _narrator.narrate(context(), played);

      expect(timeline.home.goals, 2);
      expect(timeline.away.goals, 1);
      expect(timeline.events.whereType<GoalEvent>(), hasLength(3));
      expect(timeline.home.shots, greaterThanOrEqualTo(2));
      expect(timeline.away.shots, greaterThanOrEqualTo(1));
    });

    test('files goals into the half they were scored in', () {
      // Otherwise a side that scored late would look LESS active after the
      // break, and how much a side scores carries every latent factor -- so
      // fatigue's fingerprint would be contaminated by all of them.
      final lateWinner = _narrator.narrate(
        context(),
        const MatchResult(
          homeScore: 2,
          awayScore: 0,
          events: <MatchEvent>[
            GoalEvent(minute: 70, byHome: true, playerId: null),
            GoalEvent(minute: 80, byHome: true, playerId: null),
          ],
        ),
      );
      final earlyWinner = _narrator.narrate(
        context(),
        const MatchResult(
          homeScore: 2,
          awayScore: 0,
          events: <MatchEvent>[
            GoalEvent(minute: 10, byHome: true, playerId: null),
            GoalEvent(minute: 20, byHome: true, playerId: null),
          ],
        ),
      );

      expect(lateWinner.home.shots, earlyWinner.home.shots);
      expect(
        lateWinner.home.secondHalfShots,
        earlyWinner.home.secondHalfShots + 2,
      );
    });

    test('names the scorers', () {
      final timeline = _narrator.narrate(context(), played);
      final scorers = timeline.events.whereType<GoalEvent>();

      expect(scorers.every((g) => g.playerId != null), isTrue);
      final home = timeline.homeSheet.starting.map((p) => p.id).toSet();
      for (final goal in scorers.where((g) => g.byHome)) {
        expect(home, contains(goal.playerId));
      }
    });

    test('puts everything in the order it happened', () {
      final minutes = _narrator
          .narrate(context(refereeBias: 1.5), played)
          .events
          .map((e) => e.minute)
          .toList();
      expect(minutes, orderedEquals(List<int>.of(minutes)..sort()));
    });

    test('loses a player when the injury roll says so', () {
      const always = MatchNarrator(NarrationConfig(injuryRatePerMatch: 1));
      final hurt = always.narrate(context(), played);
      final injuries = hurt.events.whereType<InjuryEvent>();

      expect(injuries, hasLength(2), reason: 'one per side');
      expect(injuries.map((e) => e.homeSide), <bool>[true, false]);
    });

    test('loses nobody when it does not', () {
      const never = MatchNarrator(NarrationConfig(injuryRatePerMatch: 0));
      expect(
        never.narrate(context(), played).events.whereType<InjuryEvent>(),
        isEmpty,
      );
    });

    test('survives a club with nobody available', () {
      // Legal, if grim: every stat still lands, and the events that need a
      // name simply do not appear.
      const wiped = MatchNarrator(
        NarrationConfig(injuryRatePerMatch: 1, redPerFoul: 1),
      );
      final timeline = wiped.narrate(
        context(home: const MatchModifiers(missingCount: 18)),
        played,
      );

      expect(timeline.homeSheet.starting, isEmpty);
      expect(timeline.home.shots, greaterThan(0));
      expect(
        timeline.events.whereType<InjuryEvent>().where((e) => e.homeSide),
        isEmpty,
      );
      expect(
        timeline.events
            .whereType<GoalEvent>()
            .where((g) => g.byHome)
            .first
            .playerId,
        isNull,
      );
    });

    test('splits the ball between the two sides and no further', () {
      final timeline = _narrator.narrate(context(), played);
      expect(
        timeline.home.possessionPercent + timeline.away.possessionPercent,
        closeTo(100, 1e-9),
      );
    });

    test('carries a team sheet for both sides', () {
      final timeline = _narrator.narrate(
        context(
          home: const MatchModifiers(missingCount: 2),
          away: const MatchModifiers(missingCount: 1),
        ),
        played,
      );
      expect(timeline.homeSheet.starting, hasLength(11));
      expect(timeline.homeSheet.missing, hasLength(2));
      expect(timeline.awaySheet.missing, hasLength(1));
    });
  });

  group('MatchTimeline.upTo', () {
    test('shows only what had happened by then', () {
      final timeline = _narrator.narrate(context(), played);
      expect(timeline.upTo(0), isEmpty);
      expect(timeline.upTo(90), hasLength(timeline.events.length));
      expect(
        timeline.upTo(45).every((e) => e.minute <= 45),
        isTrue,
      );
    });
  });

  group('TeamMatchStats', () {
    test('reports the two readable rates, and null when there is no rate', () {
      const busy = TeamMatchStats(
        goals: 2,
        shots: 10,
        secondHalfShots: 4,
        shotsOnTarget: 5,
        corners: 6,
        fouls: 11,
        yellows: 2,
        reds: 0,
        possessionPercent: 55,
      );
      expect(busy.secondHalfShotShare, 0.4);
      expect(busy.conversionRate, 0.4);
      expect(busy.toString(), contains('g2 s10(5)'));

      const nothing = TeamMatchStats(
        goals: 0,
        shots: 0,
        secondHalfShots: 0,
        shotsOnTarget: 0,
        corners: 0,
        fouls: 0,
        yellows: 0,
        reds: 0,
        possessionPercent: 50,
      );
      // Null, not zero: nobody had a shot is not "perfectly balanced".
      expect(nothing.secondHalfShotShare, isNull);
      expect(nothing.conversionRate, isNull);
    });
  });

  group('MatchRunner.narrate', () {
    test('narrates a match it just played', () {
      const runner = MatchRunner(model: DixonColesModel());
      final ctx = runner.contextFor(
        home: club(1, 'Home'),
        away: club(2, 'Away'),
        homeState: const LatentState(fatigue: 0.8),
        awayState: const LatentState(),
        seedPath: const SeedPath(master: 77, season: 0, day: 1, match: 0),
      );
      final played = runner.run(ctx);
      final timeline = runner.narrate(ctx, played);

      expect(timeline.home.goals, played.homeScore);
      expect(timeline.away.goals, played.awayScore);
      expect(timeline.homeSheet.starting, hasLength(11));
    });
  });
}
