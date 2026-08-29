import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

import 'narrator_support.dart';

const _narrator = MatchNarrator();

/// Everything about a side's match EXCEPT [except], as one comparable value.
///
/// Exact equality is the point. A tolerance-based check would let a smuggled
/// dependency hide inside sampling noise; giving every stat its own sub-seed
/// (see `NarrationSlot`) is what makes equality achievable at all.
List<Object> fingerprint(TeamMatchStats s, {String except = ''}) => <Object>[
  if (except != 'shots') s.shots,
  if (except != 'shots') s.secondHalfShots,
  if (except != 'onTarget') s.shotsOnTarget,
  if (except != 'corners') s.corners,
  if (except != 'cards') s.fouls,
  if (except != 'cards') s.yellows,
  if (except != 'cards') s.reds,
  if (except != 'possession') s.possessionPercent,
];

void main() {
  final played = result();

  group('fatigue', () {
    test('takes attempts out of the second half, and touches nothing else', () {
      var fresherHadMoreShots = 0;
      for (var seed = 0; seed < 200; seed++) {
        final fresh = _narrator.narrate(
          context(seed: seed),
          played,
        );
        final spent = _narrator.narrate(
          context(home: const MatchModifiers(lateMatchDecay: 1), seed: seed),
          played,
        );

        // Corners, cards and possession are untouched, to the last bit.
        expect(spent.home.corners, fresh.home.corners);
        expect(spent.home.fouls, fresh.home.fouls);
        expect(spent.home.possessionPercent, fresh.home.possessionPercent);
        // And the opposition's match is entirely unaffected.
        expect(fingerprint(spent.away), fingerprint(fresh.away));

        if (fresh.home.secondHalfShots > spent.home.secondHalfShots) {
          fresherHadMoreShots++;
        }
      }
      // The one thing it does move. Not every match, because a Poisson draw
      // is noisy -- but most of them.
      expect(fresherHadMoreShots, greaterThan(120));
    });
  });

  group('form', () {
    test('moves the share on target, and touches nothing else', () {
      var hotTotal = 0;
      var coldTotal = 0;
      for (var seed = 0; seed < 200; seed++) {
        final cold = _narrator.narrate(
          context(home: const MatchModifiers(formShift: -0.08), seed: seed),
          played,
        );
        final hot = _narrator.narrate(
          context(home: const MatchModifiers(formShift: 0.08), seed: seed),
          played,
        );

        expect(
          fingerprint(hot.home, except: 'onTarget'),
          fingerprint(cold.home, except: 'onTarget'),
        );
        expect(fingerprint(hot.away), fingerprint(cold.away));

        hotTotal += hot.home.shotsOnTarget;
        coldTotal += cold.home.shotsOnTarget;
      }
      expect(hotTotal, greaterThan(coldTotal));
    });
  });

  group('morale', () {
    test('moves the possession spread, and touches nothing else', () {
      final splits = <double>[];
      final calmSplits = <double>[];
      for (var seed = 0; seed < 300; seed++) {
        final fragile = _narrator.narrate(
          context(home: const MatchModifiers(moraleSpread: -0.35), seed: seed),
          played,
        );
        final confident = _narrator.narrate(
          context(home: const MatchModifiers(moraleSpread: 0.35), seed: seed),
          played,
        );

        expect(
          fingerprint(fragile.home, except: 'possession'),
          fingerprint(confident.home, except: 'possession'),
        );
        expect(
          fingerprint(fragile.away, except: 'possession'),
          fingerprint(confident.away, except: 'possession'),
        );

        splits.add(fragile.home.possessionPercent);
        calmSplits.add(confident.home.possessionPercent);
      }

      // Morale's whole fingerprint: the spread widens, the mean does not
      // move. Both halves are asserted, because either alone would pass for
      // a bug that shifted the mean.
      expect(_spread(splits), greaterThan(_spread(calmSplits)));
      expect(_mean(splits), closeTo(_mean(calmSplits), 1));
    });
  });

  group('injuries', () {
    test('change the team sheet, and touch no stat at all', () {
      for (var seed = 0; seed < 100; seed++) {
        final full = _narrator.narrate(context(seed: seed), played);
        final depleted = _narrator.narrate(
          context(home: const MatchModifiers(missingCount: 4), seed: seed),
          played,
        );

        expect(fingerprint(depleted.home), fingerprint(full.home));
        expect(fingerprint(depleted.away), fingerprint(full.away));
        expect(depleted.homeSheet.missing, hasLength(4));
        expect(full.homeSheet.missing, isEmpty);
        expect(depleted.awaySheet.missing, isEmpty);
      }
    });
  });

  group('referee bias', () {
    test('moves fouls and cards, and reaches nothing else', () {
      var strictFouls = 0;
      var lenientFouls = 0;
      for (var seed = 0; seed < 200; seed++) {
        final lenient = _narrator.narrate(
          context(refereeBias: 0.85, seed: seed),
          played,
        );
        final strict = _narrator.narrate(
          context(refereeBias: 1.15, seed: seed),
          played,
        );

        expect(
          fingerprint(strict.home, except: 'cards'),
          fingerprint(lenient.home, except: 'cards'),
        );
        expect(
          fingerprint(strict.away, except: 'cards'),
          fingerprint(lenient.away, except: 'cards'),
        );
        // And it can never reach the score, because the narrator runs after
        // the scoreline was sampled.
        expect(strict.home.goals, lenient.home.goals);

        strictFouls += strict.home.fouls;
        lenientFouls += lenient.home.fouls;
      }
      expect(strictFouls, greaterThan(lenientFouls));
    });
  });

  group('corners', () {
    test('answer to no hidden factor whatsoever', () {
      // Deliberately factor-free: texture without a fifth thing to regress
      // out. Every latent dial at once, and the count does not budge.
      final plain = _narrator.narrate(context(), played);
      final loaded = _narrator.narrate(
        context(
          home: const MatchModifiers(
            lateMatchDecay: 1,
            formShift: 0.08,
            moraleSpread: -0.35,
            missingCount: 5,
          ),
          away: const MatchModifiers(moraleSpread: 0.35),
          refereeBias: 1.4,
        ),
        played,
      );
      expect(loaded.home.corners, plain.home.corners);
      expect(loaded.away.corners, plain.away.corners);
    });
  });
}

double _mean(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;

double _spread(List<double> xs) {
  final mean = _mean(xs);
  return xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
      xs.length;
}
