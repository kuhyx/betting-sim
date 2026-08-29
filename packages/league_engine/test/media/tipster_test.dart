import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

void main() {
  group('generateTipsters', () {
    final panel = generateTipsters(20260828);

    test('is the same cast every time the save is opened', () {
      final again = generateTipsters(20260828);
      expect(again.map((t) => t.handle), panel.map((t) => t.handle));
      expect(again.map((t) => t.awareness), panel.map((t) => t.awareness));
    });

    test('a different save gets different people', () {
      expect(
        generateTipsters(999).map((t) => t.handle),
        isNot(panel.map((t) => t.handle)),
      );
    });

    test('numbers everyone in order and gives them a handle', () {
      expect(panel, hasLength(12));
      expect(panel.map((t) => t.id), List<int>.generate(12, (i) => i));
      expect(panel.every((t) => t.handle.startsWith('@')), isTrue);
      expect(panel.map((t) => t.handle).toSet(), hasLength(12));
      expect(panel.first.toString(), startsWith('Tipster(@'));
    });

    test('is mostly people who add nothing to the price', () {
      final ranked = panel.map((t) => t.awareness).toList()..sort();
      // Three worse than the odds, seven sitting on them, two genuinely
      // ahead. Reading the middle seven back to yourself is not an edge.
      expect(
        ranked.take(3).every((a) => a <= -0.05),
        isTrue,
        reason: '$ranked',
      );
      expect(
        ranked.skip(3).take(7).every((a) => a >= -0.05 && a <= 0.12),
        isTrue,
        reason: '$ranked',
      );
      expect(
        ranked.skip(10).every((a) => a >= 0.22),
        isTrue,
        reason: '$ranked',
      );
    });

    test('has exactly one confidently contrarian voice', () {
      final contrarians = panel.where(
        (t) => t.angle == TipsterAngle.contrarian,
      );
      expect(contrarians, hasLength(1));
      expect(contrarians.single.awareness, lessThan(0));
    });

    test('does not put the sharp ones first', () {
      // Otherwise "follow the top two accounts" would win without reading
      // anything. Checked across many saves, not just this one.
      var firstTwo = 0;
      for (var seed = 0; seed < 60; seed++) {
        final people = generateTipsters(seed);
        final best = people.reduce(
          (a, b) => a.awareness > b.awareness ? a : b,
        );
        if (best.id < 2) {
          firstTwo++;
        }
      }
      // 2 of 12 positions would be 10 of 60 by chance; the failure mode this
      // guards is 60 of 60.
      expect(firstTwo, lessThan(25));
    });

    test('says nothing about skill through confidence', () {
      // The whole mechanic: how loudly somebody talks is drawn independently
      // of whether they are right, so the feed cannot be read at a glance.
      var loudAndSharp = 0;
      var loudAndPoor = 0;
      for (var seed = 0; seed < 200; seed++) {
        for (final t in generateTipsters(seed)) {
          if (t.confidence > 0.8) {
            t.awareness > 0.15 ? loudAndSharp++ : loudAndPoor++;
          }
        }
      }
      expect(loudAndPoor, greaterThan(loudAndSharp * 3));
    });

    test('honours a different panel shape', () {
      final small = generateTipsters(
        7,
        const TipsterPanelConfig(count: 4, sharpCount: 1, poorCount: 1),
      );
      expect(small, hasLength(4));
      expect(small.where((t) => t.awareness >= 0.22), hasLength(1));
    });

    test('covers every angle across enough saves', () {
      final seen = <TipsterAngle>{};
      for (var seed = 0; seed < 40; seed++) {
        seen.addAll(generateTipsters(seed).map((t) => t.angle));
      }
      expect(seen, TipsterAngle.values.toSet());
    });
  });
}
