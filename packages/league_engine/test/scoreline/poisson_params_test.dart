import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

MatchContext _ctx(
  Team home,
  Team away, {
  MatchModifiers homeMods = const MatchModifiers(),
  MatchModifiers awayMods = const MatchModifiers(),
  double refereeBias = 1,
}) {
  return MatchContext(
    home: home,
    away: away,
    homeModifiers: homeMods,
    awayModifiers: awayMods,
    seedPath: const SeedPath(master: 1),
    refereeBias: refereeBias,
  );
}

void main() {
  final league = generateLeague(20260828);
  const config = ScoringConfig();

  group('scoringRates', () {
    test('the home side is favoured by venue alone', () {
      final a = league.teams[0];
      final b = league.teams[1];
      final atHome = scoringRates(_ctx(a, b), config).home;
      final away = scoringRates(_ctx(b, a), config).away;
      expect(atHome, greaterThan(away));
    });

    test('a strong attack against a weak defence scores more', () {
      final sorted = List<Team>.of(league.teams)
        ..sort((a, b) => a.attackStrength.compareTo(b.attackStrength));
      final strong = scoringRates(_ctx(sorted.last, sorted.first), config).home;
      final weak = scoringRates(_ctx(sorted.first, sorted.last), config).home;
      expect(strong, greaterThan(weak));
    });

    test('rates land in a believable range for a low-scoring sport', () {
      for (final f in league.fixtures) {
        final r = scoringRates(
          _ctx(league.teamById(f.homeId), league.teamById(f.awayId)),
          config,
        );
        expect(r.home, inExclusiveRange(0.3, 3.5));
        expect(r.away, inExclusiveRange(0.3, 3.5));
      }
    });

    test('the whole season averages roughly 2.6 goals', () {
      var total = 0.0;
      for (final f in league.fixtures) {
        final r = scoringRates(
          _ctx(league.teamById(f.homeId), league.teamById(f.awayId)),
          config,
        );
        total += r.home + r.away;
      }
      expect(total / league.fixtures.length, closeTo(2.6, 0.3));
    });

    test('referee bias moves the home rate only', () {
      final neutral = scoringRates(
        _ctx(league.teams[0], league.teams[1]),
        config,
      );
      final biased = scoringRates(
        _ctx(league.teams[0], league.teams[1], refereeBias: 1.2),
        config,
      );
      expect(biased.home, greaterThan(neutral.home));
      expect(biased.away, neutral.away);
    });

    test('rates never collapse to zero, however dire the modifiers', () {
      final r = scoringRates(
        _ctx(
          league.teams[0],
          league.teams[1],
          homeMods: const MatchModifiers(attackMultiplier: 0),
          awayMods: const MatchModifiers(attackMultiplier: 0),
        ),
        config,
      );
      expect(r.home, greaterThan(0));
      expect(r.away, greaterThan(0));
    });

    test('toString shows both rates', () {
      expect(
        const ScoringRates(home: 1.5, away: 1.25).toString(),
        'ScoringRates(1.500, 1.250)',
      );
    });
  });

  group('dixonColesTau', () {
    const rho = -0.05;

    test('adjusts exactly the four low scores it is defined for', () {
      expect(dixonColesTau(0, 0, 1.2, 1.1, rho), isNot(1));
      expect(dixonColesTau(0, 1, 1.2, 1.1, rho), isNot(1));
      expect(dixonColesTau(1, 0, 1.2, 1.1, rho), isNot(1));
      expect(dixonColesTau(1, 1, 1.2, 1.1, rho), isNot(1));
    });

    test('leaves every other score untouched', () {
      for (final score in <List<int>>[
        [2, 0],
        [0, 2],
        [2, 2],
        [3, 1],
        [5, 4],
      ]) {
        expect(
          dixonColesTau(score[0], score[1], 1.2, 1.1, rho),
          1,
          reason: '${score[0]}-${score[1]}',
        );
      }
    });

    test('a negative rho shifts mass toward the draws', () {
      // The documented shortcoming of independent Poissons: they under-predict
      // 0-0 and 1-1 and over-predict 1-0 and 0-1.
      expect(dixonColesTau(0, 0, 1.2, 1.1, rho), greaterThan(1));
      expect(dixonColesTau(1, 1, 1.2, 1.1, rho), greaterThan(1));
      expect(dixonColesTau(1, 0, 1.2, 1.1, rho), lessThan(1));
      expect(dixonColesTau(0, 1, 1.2, 1.1, rho), lessThan(1));
    });

    test('a rho of zero makes the correction inert', () {
      for (final score in <List<int>>[
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ]) {
        expect(dixonColesTau(score[0], score[1], 1.2, 1.1, 0), 1);
      }
    });
  });

  group('OutcomeProbs', () {
    test('exposes its outcomes in a fixed order for pricing', () {
      const p = OutcomeProbs(home: 0.5, draw: 0.3, away: 0.2);
      expect(p.asList, <double>[0.5, 0.3, 0.2]);
    });

    test('toString shows all three', () {
      const p = OutcomeProbs(home: 0.5, draw: 0.3, away: 0.2);
      expect(p.toString(), 'OutcomeProbs(0.500/0.300/0.200)');
    });
  });

  group('MatchResult', () {
    test('reads the result correctly', () {
      const win = MatchResult(homeScore: 2, awayScore: 1, events: []);
      const draw = MatchResult(homeScore: 1, awayScore: 1, events: []);
      const loss = MatchResult(homeScore: 0, awayScore: 1, events: []);

      expect(win.homeWon, isTrue);
      expect(win.drawn, isFalse);
      expect(draw.drawn, isTrue);
      expect(draw.homeWon, isFalse);
      expect(loss.homeWon, isFalse);
      expect(loss.drawn, isFalse);
      expect(win.toString(), 'MatchResult(2-1)');
    });
  });

  group('MatchEvent', () {
    test('each kind describes itself', () {
      expect(
        const GoalEvent(minute: 23, byHome: true, playerId: 4).toString(),
        "Goal(H 23')",
      );
      expect(
        const InjuryEvent(minute: 55, homeSide: false, playerId: 4).toString(),
        "Injury(A 55')",
      );
      expect(
        const RedCardEvent(minute: 80, homeSide: true, playerId: 4).toString(),
        "Red(H 80')",
      );
    });
  });
}
