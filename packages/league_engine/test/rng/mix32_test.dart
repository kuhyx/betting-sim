import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('mix32Next', () {
    test('frozen sequence from seed 0', () {
      // Pins the generator. These values are also asserted to be identical
      // under `dart compile js` (see DOCS-seeding.md): the engine must replay
      // a save the same way on Android and in the Chrome-wrapped web build.
      const expected = <String>[
        'e1556f64',
        'e844f99a',
        'eafff467',
        'c5d0370d',
        'dd8ebedd',
      ];

      var state = 0;
      final actual = <String>[];
      for (var i = 0; i < expected.length; i++) {
        final step = mix32Next(state);
        state = step.state;
        actual.add(hex32(step.value));
      }

      expect(actual, expected);
    });

    test('is a pure function of its input state', () {
      expect(mix32Next(12345).value, mix32Next(12345).value);
    });

    test('every output stays inside 32 bits', () {
      var state = 1;
      for (var i = 0; i < 10000; i++) {
        final step = mix32Next(state);
        state = step.state;
        expect(step.value, inInclusiveRange(0, 0xFFFFFFFF));
        expect(step.state, inInclusiveRange(0, 0xFFFFFFFF));
      }
    });
  });

  group('mul32', () {
    test('agrees with direct multiplication when it cannot overflow', () {
      expect(mul32(3, 5), 15);
      expect(mul32(65535, 2), 131070);
    });

    test('wraps at 32 bits instead of losing precision', () {
      // The case that motivates the split: a naive a*b here exceeds 2^53.
      expect(mul32(0xFFFFFFFF, 0xFFFFFFFF), u32(0xFFFFFFFF * 0xFFFFFFFF));
      expect(mul32(2246822519, 3266489917), isNot(0));
    });

    test('multiplying by zero yields zero', () {
      expect(mul32(0xDEADBEEF, 0), 0);
    });
  });

  group('u32 and hex32', () {
    test('u32 masks to the low 32 bits', () {
      expect(u32(-1), 0xFFFFFFFF);
      expect(u32(0x1FFFFFFFF), 0xFFFFFFFF);
    });

    test('hex32 pads to eight digits', () {
      expect(hex32(1), '00000001');
      expect(hex32(0xFFFFFFFF), 'ffffffff');
    });
  });
}
