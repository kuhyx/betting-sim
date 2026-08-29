import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

const _cfg = NarrationConfig();

RandomSource _seeded(int seed) => Mix32Source(seed);

void main() {
  group('drawHomePossession', () {
    test('morale scales a mean-zero term, so the mean cannot move', () {
      // The exact version of "morale changes variance, never expectation":
      // feed a normal deviate of zero and both extremes must agree to the
      // last bit, not merely to a tolerance.
      double at(double moraleSpread) => drawHomePossession(
        strengthEdge: 0,
        moraleSpread: moraleSpread,
        config: _cfg,
        rng: ScriptedRandomSource(normals: <double>[0]),
      );
      expect(at(-0.35), 50);
      expect(at(0.35), at(-0.35));
    });

    test('low morale widens the spread, high morale narrows it', () {
      double spread(double moraleSpread) {
        final values = <double>[
          for (var i = 0; i < 3000; i++)
            drawHomePossession(
              strengthEdge: 0,
              moraleSpread: moraleSpread,
              config: _cfg,
              rng: _seeded(i),
            ),
        ];
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance =
            values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
        return variance;
      }

      // Matches LatentModifiers, where low morale raises the variance
      // multiplier: fragile sides are unpredictable, not simply worse.
      expect(spread(-0.35), greaterThan(spread(0.35)));
    });

    test('a stronger side sees more of the ball', () {
      final strong = drawHomePossession(
        strengthEdge: 40,
        moraleSpread: 0,
        config: _cfg,
        rng: ScriptedRandomSource(normals: <double>[0]),
      );
      expect(strong, 60.0);
    });

    test('clamps at both ends of the pitch', () {
      double at(double deviate) => drawHomePossession(
        strengthEdge: 0,
        moraleSpread: 0,
        config: _cfg,
        rng: ScriptedRandomSource(normals: <double>[deviate]),
      );
      expect(at(-1000000), _cfg.possessionFloor);
      expect(at(1000000), _cfg.possessionCeiling);
    });
  });

  group('drawDiscipline', () {
    test('a lenient referee blows up less often', () {
      var strict = 0;
      var lenient = 0;
      for (var i = 0; i < 3000; i++) {
        strict += drawDiscipline(
          refereeBias: 1.2,
          config: _cfg,
          rng: _seeded(i),
        ).fouls;
        lenient += drawDiscipline(
          refereeBias: 0.8,
          config: _cfg,
          rng: _seeded(i),
        ).fouls;
      }
      expect(strict, greaterThan(lenient));
    });

    test('sends everyone off when the config says to', () {
      // Config-forcing, not seed-hunting: this is how the red-card branch is
      // reached without searching for a lucky match.
      final all = drawDiscipline(
        refereeBias: 1,
        config: const NarrationConfig(redPerFoul: 1),
        rng: ScriptedRandomSource(
          poissons: <int>[3],
          uniforms: <double>[0.1, 0.2, 0.3],
        ),
      );
      expect(all, (fouls: 3, yellows: 0, reds: 3));
    });

    test('books everyone when the config says to', () {
      final all = drawDiscipline(
        refereeBias: 1,
        config: const NarrationConfig(yellowPerFoul: 1, redPerFoul: 0),
        rng: ScriptedRandomSource(
          poissons: <int>[2],
          uniforms: <double>[0.4, 0.5],
        ),
      );
      expect(all, (fouls: 2, yellows: 2, reds: 0));
    });

    test('lets most fouls go unpunished', () {
      final clean = drawDiscipline(
        refereeBias: 1,
        config: _cfg,
        rng: ScriptedRandomSource(
          poissons: <int>[2],
          uniforms: <double>[0.9, 0.95],
        ),
      );
      expect(clean, (fouls: 2, yellows: 0, reds: 0));
    });

    test('takes the empty path when nothing was given', () {
      final none = drawDiscipline(
        refereeBias: 0,
        config: _cfg,
        rng: ScriptedRandomSource(poissons: <int>[0]),
      );
      expect(none, (fouls: 0, yellows: 0, reds: 0));
    });

    test('clamps a runaway referee', () {
      // A real source, not a scripted one: ScriptedRandomSource ignores the
      // lambda it is handed, so only a genuine Poisson draw can show that the
      // rate was capped. Uncapped this would be poisson(1.1e7), which Knuth's
      // method would never finish.
      final capped = drawDiscipline(
        refereeBias: 1000000,
        config: _cfg,
        rng: _seeded(7),
      );
      expect(capped.fouls, inInclusiveRange(15, 70));

      expect(
        drawDiscipline(refereeBias: -5, config: _cfg, rng: _seeded(2)).fouls,
        0,
      );
    });
  });

  group('drawInjury', () {
    test('is one draw against the configured rate', () {
      expect(
        drawInjury(
          config: _cfg,
          rng: ScriptedRandomSource(uniforms: <double>[0.01]),
        ),
        isTrue,
      );
      expect(
        drawInjury(
          config: _cfg,
          rng: ScriptedRandomSource(uniforms: <double>[0.5]),
        ),
        isFalse,
      );
    });
  });
}
