import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

const _informed = OutcomeProbs(home: 0.6, draw: 0.25, away: 0.15);
const _unaware = OutcomeProbs(home: 0.4, draw: 0.3, away: 0.3);

void main() {
  group('blendOpinions', () {
    test('is the informed view at awareness 1', () {
      final blended = blendOpinions(_informed, _unaware, 1);
      expect(blended.home, closeTo(0.6, 1e-12));
      expect(blended.away, closeTo(0.15, 1e-12));
    });

    test('is the blind view at awareness 0', () {
      final blended = blendOpinions(_informed, _unaware, 0);
      expect(blended.home, closeTo(0.4, 1e-12));
      expect(blended.draw, closeTo(0.3, 1e-12));
    });

    test('sits between them, and still sums to one', () {
      final blended = blendOpinions(_informed, _unaware, 0.5);
      expect(blended.home, closeTo(0.5, 1e-12));
      expect(blended.asList.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });

    test('extrapolates AWAY from the truth at a negative awareness', () {
      // How a tipster ends up worse than the price they are reading.
      final blended = blendOpinions(_informed, _unaware, -0.5);
      expect(blended.home, lessThan(_unaware.home));
      expect(blended.asList.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });
  });

  group('favouriteOf', () {
    test('names the shortest price', () {
      expect(favouriteOf(_informed), Selection.home);
      expect(
        favouriteOf(const OutcomeProbs(home: 0.2, draw: 0.3, away: 0.5)),
        Selection.away,
      );
      expect(
        favouriteOf(const OutcomeProbs(home: 0.2, draw: 0.5, away: 0.3)),
        Selection.draw,
      );
    });
  });

  group('normaliseOpinion', () {
    test('turns weights into probabilities', () {
      final probs = normaliseOpinion(<double>[2, 1, 1]);
      expect(probs.home, closeTo(0.5, 1e-12));
      expect(probs.asList.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });

    test('floors a component that noise pushed negative', () {
      // Without the floor this would price an impossible outcome below evens.
      final probs = normaliseOpinion(<double>[0.9, -0.4, 0.5]);
      expect(probs.draw, greaterThan(0));
      expect(probs.asList.every((p) => p > 0), isTrue);
      expect(probs.asList.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });

    test('honours a different floor', () {
      final probs = normaliseOpinion(<double>[1, 0, 0], floor: 0.5);
      expect(probs.draw, closeTo(0.25, 1e-12));
    });
  });

  group('MatchContext.latentBlind', () {
    test('strips the hidden state and keeps what is published', () {
      final ctx = MatchContext(
        home: _club(1),
        away: _club(2),
        homeModifiers: const MatchModifiers(
          attackMultiplier: 0.7,
          formShift: 0.05,
          missingCount: 3,
        ),
        awayModifiers: const MatchModifiers(varianceMultiplier: 1.4),
        seedPath: const SeedPath(master: 1),
        weather: Weather.storm,
        refereeBias: 1.1,
      );
      final blind = ctx.latentBlind;

      expect(blind.homeModifiers.attackMultiplier, 1);
      expect(blind.homeModifiers.formShift, 0);
      expect(blind.homeModifiers.missingCount, 0);
      expect(blind.awayModifiers.varianceMultiplier, 1);
      // Weather and the referee are published, so nobody is blind to them.
      expect(blind.weather, Weather.storm);
      expect(blind.refereeBias, 1.1);
      expect(blind.home, ctx.home);
    });
  });
}

Team _club(int id) => Team(
  id: id,
  name: 'C$id',
  town: 'T$id',
  players: <Player>[
    for (var i = 0; i < 18; i++)
      Player(
        id: id * 100 + i,
        name: 'p$i',
        attack: 50,
        defence: 50,
        stamina: 60,
        age: 25,
      ),
  ],
  rating: const Rating(),
);
