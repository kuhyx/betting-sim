import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

Team _club(int id, String name) => Team(
  id: id,
  name: name,
  town: 'Town$id',
  players: <Player>[
    for (var i = 0; i < 18; i++)
      Player(
        id: id * 100 + i,
        name: 'p$i',
        attack: 45.0 + i,
        defence: 50,
        stamina: 60,
        age: 25,
      ),
  ],
  rating: const Rating(),
);

MatchContext _ctx({int seed = 31}) => MatchContext(
  home: _club(1, 'Home'),
  away: _club(2, 'Away'),
  homeModifiers: const MatchModifiers(attackMultiplier: 0.8, formShift: 0.05),
  awayModifiers: const MatchModifiers(),
  seedPath: SeedPath(master: seed, season: 0, day: 0, match: 0),
);

/// A book priced off the LATENT-BLIND view, which is what a real one is:
/// mostly right and behind the news. Pricing the truth instead would leave a
/// sharp tipster nothing to add, and these tests would measure nothing.
Market _market() => const Bookmaker().price(
  const DixonColesModel().outcomeProbabilities(_ctx().latentBlind),
);

Tipster _tipster({
  double awareness = 0,
  TipsterAngle angle = TipsterAngle.straight,
  double noise = 0,
  double confidence = 0.5,
}) => Tipster(
  id: 0,
  handle: '@t',
  awareness: awareness,
  noise: noise,
  angle: angle,
  confidence: confidence,
);

void main() {
  const desk = TipsterDesk();
  final market = _market();

  List<Tip> tipsOf(List<Tipster> panel, {int seed = 31}) => desk.tipsFor(
    ctx: _ctx(seed: seed),
    path: SeedPath(master: seed, season: 0, day: 0, match: 0),
    tipsters: panel,
    market: market,
  );

  group('TipsterDesk', () {
    test('gives every tipster a call, with words on it', () {
      final tips = tipsOf(generateTipsters(31));
      expect(tips, hasLength(12));
      expect(tips.every((t) => t.text.isNotEmpty), isTrue);
      expect(tips.map((t) => t.tipsterId), List<int>.generate(12, (i) => i));
      expect(tips.first.toString(), contains(tips.first.handle));
    });

    test('replays exactly from the same address', () {
      final panel = generateTipsters(31);
      expect(
        tipsOf(panel).map((t) => t.text),
        tipsOf(panel).map((t) => t.text),
      );
    });

    test('a homer leans home, a contrarian leans off the favourite', () {
      // Same seed, same noise, only the angle differs -- so any difference is
      // the lean and nothing else.
      double believedHome(TipsterAngle angle) {
        final tips = tipsOf(<Tipster>[_tipster(angle: angle)]);
        return tips.single.selection == Selection.home
            ? tips.single.believedProbability
            : 0;
      }

      final fair = market.fairProbabilities;
      final favourite = favouriteOf(
        OutcomeProbs(home: fair[0], draw: fair[1], away: fair[2]),
      );
      expect(favourite, Selection.home, reason: 'fixture sanity');
      expect(
        believedHome(TipsterAngle.homer),
        greaterThan(believedHome(TipsterAngle.straight)),
      );
      expect(
        tipsOf(<Tipster>[_tipster(angle: TipsterAngle.contrarian)])
            .single
            .selection,
        isNot(Selection.home),
      );
      expect(
        believedHome(TipsterAngle.favourite),
        greaterThan(believedHome(TipsterAngle.straight)),
      );
    });

    test('a tipster at zero awareness cannot beat the price', () {
      // They are reading the odds back to you. Averaged over fixtures their
      // edge is nil, which is why following the crowd loses the vig.
      var edge = 0.0;
      for (var seed = 0; seed < 120; seed++) {
        final tips = desk.tipsFor(
          ctx: _ctx(seed: seed),
          path: SeedPath(master: seed, season: 0, day: 0, match: 0),
          tipsters: <Tipster>[_tipster()],
          market: market,
        );
        edge +=
            tips.single.believedProbability -
            market.fairProbabilities[tips.single.selection.index];
      }
      expect(edge / 120, closeTo(0, 0.02));
    });

    test('a sharp tipster disagrees with the price more than a blind one', () {
      double spread(double awareness) {
        var total = 0.0;
        for (var seed = 0; seed < 60; seed++) {
          final tip = desk
              .tipsFor(
                ctx: _ctx(seed: seed),
                path: SeedPath(master: seed, season: 0, day: 0, match: 0),
                tipsters: <Tipster>[_tipster(awareness: awareness)],
                market: market,
              )
              .single;
          total += tip.edgeAgainst(market).abs();
        }
        return total / 60;
      }

      expect(spread(0.35), greaterThan(spread(0)));
    });

    test('the whole panel shares an error on each fixture', () {
      // Correlated error is what stops averaging twelve opinions from
      // cancelling the noise and leaving the truth. Turn it off and the
      // consensus sharpens; that build returned +12.8% to the crowd.
      double consensusSpread(TipConfig config) {
        final panel = <Tipster>[
          for (var i = 0; i < 8; i++)
            Tipster(
              id: i,
              handle: '@t$i',
              awareness: 0,
              noise: 0.03,
              angle: TipsterAngle.straight,
              confidence: 0.5,
            ),
        ];
        final tips = TipsterDesk(config: config).tipsFor(
          ctx: _ctx(),
          path: const SeedPath(master: 31, season: 0, day: 0, match: 0),
          tipsters: panel,
          market: market,
        );
        final home = tips.where((t) => t.selection == Selection.home).length;
        return home / tips.length;
      }

      final shared = consensusSpread(const TipConfig());
      final independent = consensusSpread(const TipConfig(panelNoise: 0));
      expect(shared, isNot(equals(independent)));
    });

    test('never quotes an impossible probability', () {
      // Noise and lean can push a component negative before normalising.
      final wild = <Tipster>[
        for (var i = 0; i < 12; i++)
          Tipster(
            id: i,
            handle: '@w$i',
            awareness: -0.9,
            noise: 0.5,
            angle: TipsterAngle.contrarian,
            confidence: 1,
          ),
      ];
      for (var seed = 0; seed < 40; seed++) {
        for (final tip in desk.tipsFor(
          ctx: _ctx(seed: seed),
          path: SeedPath(master: seed, season: 0, day: 0, match: 0),
          tipsters: wild,
          market: market,
        )) {
          expect(tip.believedProbability, greaterThan(0));
          expect(tip.believedProbability, lessThan(1));
        }
      }
    });

    test('tips every selection across enough fixtures', () {
      final seen = <Selection>{};
      for (var seed = 0; seed < 40; seed++) {
        seen.addAll(
          desk
              .tipsFor(
                ctx: _ctx(seed: seed),
                path: SeedPath(master: seed, season: 0, day: 0, match: 0),
                tipsters: generateTipsters(seed),
                market: market,
              )
              .map((t) => t.selection),
        );
      }
      expect(seen, Selection.values.toSet());
    });
  });
}
