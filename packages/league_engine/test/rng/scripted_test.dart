import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptedRandomSource', () {
    test('replays each queue in order', () {
      final rng = ScriptedRandomSource(
        uniforms: [0.1, 0.9],
        ints: [3],
        normals: [1.5],
        poissons: [2],
      );
      expect(rng.uniform01(), 0.1);
      expect(rng.uniform01(), 0.9);
      expect(rng.randint(0, 10), 3);
      expect(rng.normal(0, 1), 1.5);
      expect(rng.poisson(1), 2);
    });

    test('queues are independent of one another', () {
      // Scripting an injury roll must not require supplying every unrelated
      // uniform draw the surrounding code happens to make.
      final rng = ScriptedRandomSource(poissons: [4]);
      expect(rng.poisson(1.2), 4);
    });

    test('exhausting a queue fails loudly rather than inventing a draw', () {
      final rng = ScriptedRandomSource(uniforms: [0.5]);
      expect(rng.uniform01(), 0.5);
      expect(rng.uniform01, throwsStateError);
    });

    test('an unscripted queue is exhausted immediately', () {
      final rng = ScriptedRandomSource();
      expect(rng.uniform01, throwsStateError);
      expect(() => rng.randint(0, 1), throwsStateError);
      expect(() => rng.normal(0, 1), throwsStateError);
      expect(() => rng.poisson(1), throwsStateError);
    });

    test('is a RandomSource, so it substitutes anywhere', () {
      final RandomSource rng = ScriptedRandomSource(uniforms: [0.25]);
      expect(rng.uniform01(), 0.25);
    });
  });
}
