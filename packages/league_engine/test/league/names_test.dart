import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('MarkovNamer', () {
    RandomSource rng() => Mix32Source(deriveSeed(const SeedPath(master: 42)));

    test('is deterministic for a given source', () {
      final a = MarkovNamer(townCorpus).generate(rng());
      final b = MarkovNamer(townCorpus).generate(rng());
      expect(a, b);
    });

    test('never emits a corpus entry verbatim', () {
      // The league must not field a town that already exists in the training
      // data -- that is what makes the world feel invented rather than copied.
      final namer = MarkovNamer(townCorpus);
      final source = rng();
      final lower = townCorpus.map((s) => s.toLowerCase()).toSet();
      for (var i = 0; i < 500; i++) {
        expect(lower.contains(namer.generate(source).toLowerCase()), isFalse);
      }
    });

    test('respects the requested length bounds', () {
      final namer = MarkovNamer(townCorpus);
      final source = rng();
      for (var i = 0; i < 300; i++) {
        final name = namer.generate(source, minLength: 6);
        expect(name.length, inInclusiveRange(6, 11));
      }
    });

    test('capitalises its output', () {
      final name = MarkovNamer(townCorpus).generate(rng());
      expect(name[0], name[0].toUpperCase());
    });

    test('produces variety rather than one favourite', () {
      final namer = MarkovNamer(townCorpus);
      final source = rng();
      final names = <String>{
        for (var i = 0; i < 200; i++) namer.generate(source),
      };
      expect(names.length, greaterThan(50));
    });

    test('falls back to a blend when the chain cannot satisfy the bounds', () {
      // A single-entry corpus can only walk to that entry, which is rejected
      // as verbatim; the blend path is what keeps the caller supplied.
      final namer = MarkovNamer(['onlyword']);
      final name = namer.generate(rng(), minLength: 3, maxLength: 20);
      expect(name, isNotEmpty);
      expect(name[0], name[0].toUpperCase());
    });

    test('pads a blend that falls short of the minimum', () {
      final namer = MarkovNamer(['ab']);
      final name = namer.generate(rng(), minLength: 8, maxLength: 20);
      expect(name.length, greaterThanOrEqualTo(8));
    });

    test('truncates a blend that overshoots the maximum', () {
      final namer = MarkovNamer(['abcdefghijklmnopqrstuvwxyz']);
      final name = namer.generate(rng(), minLength: 2, maxLength: 6);
      expect(name.length, lessThanOrEqualTo(6));
    });
  });
}
