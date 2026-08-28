import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const modifiers = LatentModifiers();

  group('fingerprints are distinct', () {
    // The whole game rests on this. If two hidden factors moved the same
    // observable in the same way, no amount of study could separate them and
    // the simulation would be an unlearnable slot machine.

    test('morale moves variance and NOTHING else', () {
      for (final morale in <double>[-1, -0.5, 0, 0.5, 1]) {
        final m = modifiers.project(LatentState(morale: morale));
        expect(m.attackMultiplier, 1, reason: 'morale must not shift the mean');
        expect(m.defenceMultiplier, 1);
        expect(m.lateMatchDecay, 0);
      }
      expect(
        modifiers.project(const LatentState(morale: -1)).varianceMultiplier,
        greaterThan(
          modifiers.project(const LatentState(morale: 1)).varianceMultiplier,
        ),
      );
    });

    test('fatigue moves scoring and late decay, but not variance', () {
      final fresh = modifiers.project(const LatentState());
      final spent = modifiers.project(const LatentState(fatigue: 1));

      expect(spent.attackMultiplier, lessThan(fresh.attackMultiplier));
      expect(spent.lateMatchDecay, greaterThan(fresh.lateMatchDecay));
      expect(spent.varianceMultiplier, fresh.varianceMultiplier);
    });

    test('form shifts the mean without touching variance', () {
      final cold = modifiers.project(const LatentState(form: -1));
      final hot = modifiers.project(const LatentState(form: 1));

      expect(hot.attackMultiplier, greaterThan(cold.attackMultiplier));
      expect(hot.varianceMultiplier, cold.varianceMultiplier);
      expect(hot.lateMatchDecay, cold.lateMatchDecay);
    });

    test('injuries cut scoring in steps, without touching variance', () {
      final full = modifiers.project(const LatentState());
      final depleted = modifiers.project(const LatentState(injuredCount: 4));

      expect(depleted.attackMultiplier, lessThan(full.attackMultiplier));
      expect(depleted.varianceMultiplier, full.varianceMultiplier);
    });
  });

  group('weather', () {
    test('clear weather changes nothing', () {
      final m = modifiers.project(const LatentState());
      expect(m.attackMultiplier, 1);
      expect(m.varianceMultiplier, 1);
    });

    test('rain suppresses scoring but not variance', () {
      final m = modifiers.project(const LatentState(), weather: Weather.rain);
      expect(m.attackMultiplier, lessThan(1));
      expect(m.varianceMultiplier, 1);
    });

    test('a storm suppresses scoring AND levels the sides', () {
      final m = modifiers.project(const LatentState(), weather: Weather.storm);
      expect(m.attackMultiplier, lessThan(1));
      expect(m.varianceMultiplier, greaterThan(1));
    });

    test('a storm is harsher than rain', () {
      final rain = modifiers.project(
        const LatentState(),
        weather: Weather.rain,
      );
      final storm = modifiers.project(
        const LatentState(),
        weather: Weather.storm,
      );
      expect(storm.attackMultiplier, lessThan(rain.attackMultiplier));
    });
  });

  group('bounds', () {
    test('multipliers never go negative, however bad things get', () {
      const dire = LatentConfig(
        fatigueAttackPenalty: 5,
        injuryAttackPenalty: 5,
        moraleVarianceSpread: 5,
      );
      final m = const LatentModifiers(dire).project(
        const LatentState(fatigue: 1, injuredCount: 11, morale: 1),
      );
      expect(m.attackMultiplier, greaterThanOrEqualTo(0));
      expect(m.defenceMultiplier, greaterThanOrEqualTo(0));
      expect(m.varianceMultiplier, greaterThanOrEqualTo(0));
    });

    test('late-match decay stays within 0..1', () {
      final m = modifiers.project(const LatentState(fatigue: 1));
      expect(m.lateMatchDecay, inInclusiveRange(0, 1));
    });
  });

  test('toString summarises the effects', () {
    expect(
      modifiers.project(const LatentState()).toString(),
      contains('atk 1.000'),
    );
  });
}
