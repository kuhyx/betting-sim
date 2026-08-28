import 'package:betting_sim/state/tuning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_engine/league_engine.dart';

void main() {
  group('Tuning', () {
    test('defaults match the shipped engine values', () {
      const tuning = Tuning();

      // These are asserted against the ENGINE's own defaults rather than
      // repeated as literals: the app must start the game the acceptance gate
      // measures, and a silent drift between the two would retune the shipped
      // build without anyone touching a knob.
      const runner = SeasonRunner();
      const scoring = ScoringConfig();
      const latent = LatentConfig();

      expect(tuning.bookLatentAwareness, runner.bookLatentAwareness);
      expect(tuning.strengthScale, scoring.strengthScale);
      expect(tuning.fatigueAttackPenalty, latent.fatigueAttackPenalty);
      expect(tuning.margin, 0.05);
    });

    test('copyWith replaces one field and leaves the rest', () {
      const base = Tuning();

      expect(base.copyWith(bookLatentAwareness: 0.5).bookLatentAwareness, 0.5);
      expect(base.copyWith(bookLatentAwareness: 0.5).margin, base.margin);
      expect(base.copyWith(strengthScale: 0.01).strengthScale, 0.01);
      expect(base.copyWith(fatigueAttackPenalty: 0.4).fatigueAttackPenalty, .4);
      expect(base.copyWith(margin: 0.1).margin, 0.1);
    });

    test('copyWith with no arguments changes nothing', () {
      const base = Tuning();
      expect(base.copyWith(), base);
    });

    test('the derived engine objects carry the knob values', () {
      const tuning = Tuning(
        strengthScale: 0.01,
        fatigueAttackPenalty: 0.4,
        margin: 0.08,
      );

      expect(tuning.model.config.strengthScale, 0.01);
      expect(tuning.latentConfig.fatigueAttackPenalty, 0.4);
      expect(tuning.bookmaker.marginMethod, isA<ProportionalMargin>());
    });

    test('the bookmaker actually charges the tuned margin', () {
      // The knob is worthless if it does not reach the prices, so this asserts
      // the overround on a real market rather than the field it was built from.
      const probs = OutcomeProbs(home: 0.5, draw: 0.25, away: 0.25);

      expect(
        const Tuning(margin: 0.08).bookmaker.price(probs).margin,
        closeTo(0.08, 1e-9),
      );
      expect(
        const Tuning().bookmaker.price(probs).margin,
        closeTo(0.05, 1e-9),
      );
    });

    test('equality and hashCode cover every field', () {
      const base = Tuning();

      expect(base, const Tuning());
      expect(base.hashCode, const Tuning().hashCode);
      expect(base, isNot(base.copyWith(bookLatentAwareness: 0.5)));
      expect(base, isNot(base.copyWith(strengthScale: 0.01)));
      expect(base, isNot(base.copyWith(fatigueAttackPenalty: 0.4)));
      expect(base, isNot(base.copyWith(margin: 0.1)));
      expect(base, isNot(const Object()));
    });
  });
}
