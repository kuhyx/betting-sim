import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

StrategyMetrics _oracle(double roi) => summarise('oracle', <SeasonResult>[
  for (var i = 0; i < 20; i++)
    SeasonResult(
      matchdays: <MatchdayResult>[
        MatchdayResult(
          day: 0,
          bets: <SettledBet>[
            SettledBet(
              bet: const Bet(
                selection: Selection.home,
                stake: 100,
                taken: Odds(2),
              ),
              profit: roi * 100,
              closingLineValue: 0,
            ),
          ],
        ),
      ],
      bettorName: 'oracle',
    ),
]);

LifeResult _life({
  required RunEnding ending,
  double bankroll = 500,
  double energy = 0.5,
  bool starved = false,
  int days = 266,
}) => LifeResult(
  plannerName: 'test',
  household: Household(bankroll: bankroll, ending: ending),
  needs: Needs(energy: energy),
  daysLived: days,
  everStarved: starved,
);

void main() {
  group('gate 6a: a working life is affordable', () {
    test('passes when the grafter finishes housed, fed and solvent', () {
      final result = gateAWorkingLifeIsAffordable(
        _life(ending: RunEnding.survived),
      );
      expect(result.passed, isTrue);
      expect(result.detail, contains('survived on 500'));
    });

    test('fails when working full time still loses the flat', () {
      expect(
        gateAWorkingLifeIsAffordable(_life(ending: RunEnding.evicted)).passed,
        isFalse,
      );
    });

    test('fails when surviving meant not eating', () {
      expect(
        gateAWorkingLifeIsAffordable(
          _life(ending: RunEnding.survived, starved: true),
        ).passed,
        isFalse,
      );
    });

    test('fails when you end the season broke or on your knees', () {
      expect(
        gateAWorkingLifeIsAffordable(
          _life(ending: RunEnding.survived, bankroll: 0),
        ).passed,
        isFalse,
      );
      expect(
        gateAWorkingLifeIsAffordable(
          _life(ending: RunEnding.survived, energy: 0),
        ).passed,
        isFalse,
      );
    });
  });

  group('gate 6b: betting is not a living', () {
    final idler = _life(ending: RunEnding.evicted, days: 26);

    test('passes when a season of rent dwarfs perfect knowledge', () {
      final result = gateBettingIsNotALiving(_oracle(0.2), idler);
      expect(result.passed, isTrue);
      expect(result.detail, contains('12160'));
      expect(result.detail, contains('evicted on day 26'));
    });

    test('fails if a bankroll could ever be an income', () {
      // If the oracle's season were worth a year of rent, the floor under the
      // bankroll would stop being a floor.
      expect(
        gateBettingIsNotALiving(_oracle(20), idler).passed,
        isFalse,
      );
    });

    test('fails if somebody can stop working and get away with it', () {
      expect(
        gateBettingIsNotALiving(
          _oracle(0.2),
          _life(ending: RunEnding.survived),
        ).passed,
        isFalse,
      );
    });

    test('honours a different ratio and a shorter season', () {
      final result = gateBettingIsNotALiving(
        _oracle(0.2),
        idler,
        weeks: 4,
        gateConfig: const LifeGateConfig(minRentToEdgeRatio: 100),
      );
      expect(result.passed, isFalse);
      expect(result.detail, contains('1280'));
    });

    test('honours a different rent', () {
      final result = gateBettingIsNotALiving(
        _oracle(0.2),
        idler,
        config: const LifeConfig(rentPerWeek: 500),
        openingBankroll: 2000,
      );
      expect(result.passed, isTrue);
      expect(result.detail, contains('19000'));
    });
  });
}
