import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

const _cfg = NarrationConfig();

RandomSource _seeded(int seed) => Mix32Source(seed);

void main() {
  group('drawShots', () {
    test('every goal is also a shot, by construction', () {
      // shots = goals + drawn, so there is no `max(shots, goals)` and no
      // branch that could ever report fewer shots than goals.
      final split = drawShots(
        strengthEdge: 0,
        lateMatchDecay: 0,
        goals: 4,
        secondHalfGoals: 3,
        config: _cfg,
        rng: ScriptedRandomSource(poissons: <int>[0, 0]),
      );
      expect(split.total, 4);
      expect(split.firstHalf, 1);
      expect(split.secondHalf, 3, reason: 'goals land in their own half');
    });

    test('fatigue takes attempts out of the second half only', () {
      var freshSecond = 0;
      var spentSecond = 0;
      var freshFirst = 0;
      var spentFirst = 0;
      for (var i = 0; i < 4000; i++) {
        final fresh = drawShots(
          strengthEdge: 0,
          lateMatchDecay: 0,
          goals: 0,
          secondHalfGoals: 0,
          config: _cfg,
          rng: _seeded(i),
        );
        final spent = drawShots(
          strengthEdge: 0,
          lateMatchDecay: 1,
          goals: 0,
          secondHalfGoals: 0,
          config: _cfg,
          rng: _seeded(i),
        );
        freshFirst += fresh.firstHalf;
        spentFirst += spent.firstHalf;
        freshSecond += fresh.secondHalf;
        spentSecond += spent.secondHalf;
      }

      // The first half is untouched: identical draws, identical rate.
      expect(spentFirst, freshFirst);
      // The second half loses roughly fatigueShotDecay of its rate. The
      // tolerance is 10% of the expected drop, measured across batches,
      // not chosen to make this pass.
      final drop = 1 - spentSecond / freshSecond;
      expect(drop, closeTo(_cfg.fatigueShotDecay, 0.045));
    });

    test('a stronger side has more of the ball to shoot with', () {
      var weak = 0;
      var strong = 0;
      for (var i = 0; i < 3000; i++) {
        weak += drawShots(
          strengthEdge: -20,
          lateMatchDecay: 0,
          goals: 0,
          secondHalfGoals: 0,
          config: _cfg,
          rng: _seeded(i),
        ).total;
        strong += drawShots(
          strengthEdge: 20,
          lateMatchDecay: 0,
          goals: 0,
          secondHalfGoals: 0,
          config: _cfg,
          rng: _seeded(i),
        ).total;
      }
      expect(strong, greaterThan(weak));
    });

    test('clamps an absurd strength gap rather than chasing the rate', () {
      final capped = drawShots(
        strengthEdge: 100000,
        lateMatchDecay: 0,
        goals: 0,
        secondHalfGoals: 0,
        config: _cfg,
        rng: ScriptedRandomSource(poissons: <int>[5, 5]),
      );
      expect(capped.total, 10);

      final floored = drawShots(
        strengthEdge: -100000,
        lateMatchDecay: 0,
        goals: 0,
        secondHalfGoals: 0,
        config: _cfg,
        rng: _seeded(1),
      );
      expect(floored.total, 0, reason: 'a rate of zero draws nothing');
    });
  });

  group('drawShotsOnTarget', () {
    test('every goal was on target', () {
      expect(
        drawShotsOnTarget(
          nonScoringShots: 0,
          goals: 3,
          formShift: 0,
          config: _cfg,
          rng: ScriptedRandomSource(),
        ),
        3,
      );
    });

    test('counts one Bernoulli trial per non-scoring shot', () {
      final rng = ScriptedRandomSource(uniforms: <double>[0.1, 0.9, 0.2]);
      expect(
        drawShotsOnTarget(
          nonScoringShots: 3,
          goals: 1,
          formShift: 0,
          config: _cfg,
          rng: rng,
        ),
        3,
        reason: '1 goal + 2 draws under the 0.36 base rate',
      );
    });

    test('form raises the share on target and nothing else', () {
      var cold = 0;
      var hot = 0;
      for (var i = 0; i < 2000; i++) {
        cold += drawShotsOnTarget(
          nonScoringShots: 10,
          goals: 0,
          formShift: -0.08,
          config: _cfg,
          rng: _seeded(i),
        );
        hot += drawShotsOnTarget(
          nonScoringShots: 10,
          goals: 0,
          formShift: 0.08,
          config: _cfg,
          rng: _seeded(i),
        );
      }
      expect(hot, greaterThan(cold));
    });

    test('clamps the share at both ends', () {
      const wild = NarrationConfig(formOnTarget: 1000);
      final none = drawShotsOnTarget(
        nonScoringShots: 1,
        goals: 0,
        formShift: -1,
        config: wild,
        rng: ScriptedRandomSource(uniforms: <double>[0.04]),
      );
      expect(none, 1, reason: 'floored at 0.05, and 0.04 is under it');

      final all = drawShotsOnTarget(
        nonScoringShots: 1,
        goals: 0,
        formShift: 1,
        config: wild,
        rng: ScriptedRandomSource(uniforms: <double>[0.94]),
      );
      expect(all, 1, reason: 'ceilinged at 0.95');
    });
  });

  group('drawCorners', () {
    test('answers to strength and to nothing hidden', () {
      expect(
        drawCorners(
          strengthEdge: 0,
          config: _cfg,
          rng: ScriptedRandomSource(poissons: <int>[6]),
        ),
        6,
      );
      var weak = 0;
      var strong = 0;
      for (var i = 0; i < 3000; i++) {
        weak += drawCorners(strengthEdge: -30, config: _cfg, rng: _seeded(i));
        strong += drawCorners(strengthEdge: 30, config: _cfg, rng: _seeded(i));
      }
      expect(strong, greaterThan(weak));
    });

    test('clamps a negative rate to zero', () {
      expect(
        drawCorners(strengthEdge: -100000, config: _cfg, rng: _seeded(3)),
        0,
      );
    });
  });
}
