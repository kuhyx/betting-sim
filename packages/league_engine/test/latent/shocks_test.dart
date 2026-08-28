import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('rollInjury', () {
    test('fires when the config makes it certain', () {
      // Technique (b): override the config to force a rare branch through the
      // real code path, with no stubbing and no seed search.
      const certain = LatentConfig(injuryBaseRate: 1);
      expect(
        const LatentShocks(certain)
            .rollInjury(const LatentState(), Mix32Source(1)),
        isTrue,
      );
    });

    test('never fires when the rate is zero', () {
      const never = LatentConfig(injuryBaseRate: 0, injuryFatigueScaling: 0);
      final rng = Mix32Source(1);
      for (var i = 0; i < 200; i++) {
        expect(
          const LatentShocks(never).rollInjury(const LatentState(), rng),
          isFalse,
        );
      }
    });

    test('a tired squad gets injured more often', () {
      // The mechanism linking a congested fixture list to a thin squad --
      // a chain the player can learn to anticipate from the schedule alone.
      const shocks = LatentShocks();
      var freshInjuries = 0;
      var tiredInjuries = 0;
      final fresh = Mix32Source(11);
      final tired = Mix32Source(11);
      for (var i = 0; i < 20000; i++) {
        if (shocks.rollInjury(const LatentState(), fresh)) {
          freshInjuries++;
        }
        if (shocks.rollInjury(const LatentState(fatigue: 1), tired)) {
          tiredInjuries++;
        }
      }
      expect(tiredInjuries, greaterThan(freshInjuries));
    });

    test('uses a scripted draw exactly once', () {
      // Technique (a): the scripted source reaches the branch
      // deterministically, with no seed search.
      final rng = ScriptedRandomSource(uniforms: [0.001]);
      expect(
        const LatentShocks().rollInjury(const LatentState(), rng),
        isTrue,
      );
      expect(rng.uniform01, throwsStateError);
    });
  });

  group('rollWeather', () {
    test('a low roll is a storm, a high roll is clear', () {
      const shocks = LatentShocks();
      expect(
        shocks.rollWeather(ScriptedRandomSource(uniforms: [0.0])),
        Weather.storm,
      );
      expect(
        shocks.rollWeather(ScriptedRandomSource(uniforms: [0.99])),
        Weather.clear,
      );
    });

    test('the middle band is rain', () {
      // stormProbability 0.07, rainProbability 0.22 -> rain spans 0.07..0.29.
      expect(
        const LatentShocks().rollWeather(
          ScriptedRandomSource(uniforms: [0.15]),
        ),
        Weather.rain,
      );
    });

    test('the bands are contiguous and exclusive at the top', () {
      // Deliberately NOT asserted at exactly 0.29: the threshold is computed
      // as 0.07 + 0.22, which is 0.29000000000000004 in binary floating point,
      // so 0.29 is still rain. Pinning a knife-edge would be testing IEEE-754,
      // not the weather model.
      const shocks = LatentShocks();
      expect(
        shocks.rollWeather(ScriptedRandomSource(uniforms: [0.07])),
        Weather.rain,
        reason: 'the storm band excludes its own upper bound',
      );
      expect(
        shocks.rollWeather(ScriptedRandomSource(uniforms: [0.2901])),
        Weather.clear,
      );
    });

    test('over a season the mix is roughly as configured', () {
      const shocks = LatentShocks();
      final rng = Mix32Source(7);
      var storms = 0;
      var rains = 0;
      const n = 40000;
      for (var i = 0; i < n; i++) {
        switch (shocks.rollWeather(rng)) {
          case Weather.storm:
            storms++;
          case Weather.rain:
            rains++;
          case Weather.clear:
            break;
        }
      }
      expect(storms / n, closeTo(0.07, 0.01));
      expect(rains / n, closeTo(0.22, 0.01));
    });
  });

  group('rollRefereeBias', () {
    test('is centred on 1 so it washes out over a season', () {
      // A referee who systematically favoured one side would be a permanent
      // edge rather than per-match noise.
      const shocks = LatentShocks();
      final rng = Mix32Source(3);
      var total = 0.0;
      const n = 50000;
      for (var i = 0; i < n; i++) {
        total += shocks.rollRefereeBias(rng);
      }
      expect(total / n, closeTo(1, 0.005));
    });

    test('a zero spread removes the effect entirely', () {
      const flat = LatentConfig(refereeBiasSpread: 0);
      expect(
        const LatentShocks(flat).rollRefereeBias(Mix32Source(1)),
        1,
      );
    });
  });

  group('recoverInjuries', () {
    test('a fit squad stays fit', () {
      expect(
        const LatentShocks().recoverInjuries(const LatentState(), 100),
        0,
      );
    });

    test('a player returns once the lay-off has elapsed', () {
      const shocks = LatentShocks();
      const injured = LatentState(injuredCount: 2);
      expect(shocks.recoverInjuries(injured, 20), 2, reason: 'still out');
      expect(shocks.recoverInjuries(injured, 21), 1, reason: 'one back');
    });
  });
}
