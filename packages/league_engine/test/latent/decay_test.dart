import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  const decay = LatentDecay();

  group('rest', () {
    test('sheds fatigue', () {
      final rested = decay.rest(const LatentState(fatigue: 0.5));
      expect(rested.fatigue, lessThan(0.5));
    });

    test('fatigue never goes below zero', () {
      final rested = decay.rest(const LatentState(fatigue: 0.01), days: 10);
      expect(rested.fatigue, 0);
    });

    test('morale and form drift back toward neutral', () {
      final rested = decay.rest(const LatentState(morale: 0.8, form: -0.8));
      expect(rested.morale, lessThan(0.8));
      expect(rested.morale, greaterThan(0));
      expect(rested.form, greaterThan(-0.8));
      expect(rested.form, lessThan(0));
    });

    test('a long lay-off returns a club to average', () {
      // This is what stops one hot streak marking a club forever.
      final rested = decay.rest(
        const LatentState(fatigue: 1, morale: 1, form: -1),
        days: 60,
      );
      expect(rested.fatigue, 0);
      expect(rested.morale, closeTo(0, 0.01));
      expect(rested.form, closeTo(0, 0.01));
    });

    test('resting zero days changes nothing', () {
      const state = LatentState(fatigue: 0.4, morale: 0.3);
      final same = decay.rest(state, days: 0);
      expect(same.fatigue, state.fatigue);
      expect(same.morale, state.morale);
    });
  });

  group('afterMatch', () {
    test('playing adds fatigue whatever the result', () {
      for (final outcome in MatchOutcome.values) {
        final after = decay.afterMatch(const LatentState(), outcome);
        expect(after.fatigue, greaterThan(0), reason: outcome.name);
      }
    });

    test('a win lifts morale and form', () {
      final after = decay.afterMatch(const LatentState(), MatchOutcome.win);
      expect(after.morale, greaterThan(0));
      expect(after.form, greaterThan(0));
    });

    test('a defeat drops morale and form', () {
      final after = decay.afterMatch(const LatentState(), MatchOutcome.loss);
      expect(after.morale, lessThan(0));
      expect(after.form, lessThan(0));
    });

    test('a draw barely moves morale and leaves form alone', () {
      final after = decay.afterMatch(const LatentState(), MatchOutcome.draw);
      expect(after.morale, closeTo(0, 0.05));
      expect(after.form, 0);
    });

    test('defeat hurts more than victory helps', () {
      // Asymmetric on purpose: it is what makes a slump self-sustaining and
      // gives a losing run its own observable signature.
      final won = decay.afterMatch(const LatentState(), MatchOutcome.win);
      final lost = decay.afterMatch(const LatentState(), MatchOutcome.loss);
      expect(lost.morale.abs(), greaterThan(won.morale.abs()));
    });

    test('fatigue saturates at 1', () {
      var state = const LatentState();
      for (var i = 0; i < 20; i++) {
        state = decay.afterMatch(state, MatchOutcome.win);
      }
      expect(state.fatigue, 1);
    });

    test('morale and form saturate at their bounds', () {
      var winning = const LatentState();
      var losing = const LatentState();
      for (var i = 0; i < 40; i++) {
        winning = decay.afterMatch(winning, MatchOutcome.win);
        losing = decay.afterMatch(losing, MatchOutcome.loss);
      }
      expect(winning.morale, lessThanOrEqualTo(1));
      expect(winning.form, lessThanOrEqualTo(1));
      expect(losing.morale, greaterThanOrEqualTo(-1));
      expect(losing.form, greaterThanOrEqualTo(-1));
    });
  });

  group('LatentState', () {
    test('copyWith replaces only what it is given', () {
      const s = LatentState(
        fatigue: 0.3,
        morale: 0.4,
        form: 0.5,
        injuredCount: 2,
      );
      expect(s.copyWith(fatigue: 0.9).fatigue, 0.9);
      expect(s.copyWith(fatigue: 0.9).morale, 0.4);
      expect(s.copyWith(morale: 0).morale, 0);
      expect(s.copyWith(form: 0).form, 0);
      expect(s.copyWith(injuredCount: 5).injuredCount, 5);
      expect(s.copyWith().fatigue, 0.3);
    });

    test('toString summarises the hidden state', () {
      expect(
        const LatentState(
          fatigue: 0.25,
          morale: -0.5,
          injuredCount: 1,
        ).toString(),
        'LatentState(fatigue 0.25, morale -0.50, injured 1)',
      );
    });
  });
}
