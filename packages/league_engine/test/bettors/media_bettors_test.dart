import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

Market _market() => const Bookmaker().price(
  const OutcomeProbs(home: 0.5, draw: 0.27, away: 0.23),
);

Tip _tip({
  required int id,
  required Selection selection,
  double confidence = 0.5,
  double believed = 0.6,
}) => Tip(
  tipsterId: id,
  handle: '@t$id',
  selection: selection,
  believedProbability: believed,
  confidence: confidence,
  text: 'words',
);

BettingView _view(List<Tip> tips) => BettingView(
  market: _market(),
  context: MatchContext(
    home: _club(1),
    away: _club(2),
    homeModifiers: const MatchModifiers(),
    awayModifiers: const MatchModifiers(),
    seedPath: const SeedPath(master: 1),
  ),
  tips: tips,
);

Team _club(int id) => Team(
  id: id,
  name: 'C$id',
  town: 'T$id',
  players: const <Player>[],
  rating: const Rating(),
);

final _rng = ScriptedRandomSource();

void main() {
  group('CrowdBettor', () {
    test('backs whatever is loudest, not whatever is commonest', () {
      // Three quiet voices on the draw against one shouted call on home.
      // Confidence carries no information about being right, which is
      // exactly why this strategy is a control rather than a strategy.
      final bets = const CrowdBettor().betsFor(
        _view(<Tip>[
          _tip(id: 0, selection: Selection.draw, confidence: 0.2),
          _tip(id: 1, selection: Selection.draw, confidence: 0.2),
          _tip(id: 2, selection: Selection.draw, confidence: 0.2),
          _tip(id: 3, selection: Selection.home, confidence: 1),
        ]),
        1000,
        _rng,
      );
      expect(bets.single.selection, Selection.home);
      expect(bets.single.stake, 10);
    });

    test('follows the consensus when it is a consensus', () {
      final bets = const CrowdBettor().betsFor(
        _view(<Tip>[
          _tip(id: 0, selection: Selection.away, confidence: 0.6),
          _tip(id: 1, selection: Selection.away, confidence: 0.6),
          _tip(id: 2, selection: Selection.home, confidence: 0.9),
        ]),
        1000,
        _rng,
      );
      expect(bets.single.selection, Selection.away);
    });

    test('sits out when nobody has posted', () {
      expect(const CrowdBettor().betsFor(_view(<Tip>[]), 1000, _rng), isEmpty);
    });

    test('never stakes more than it has', () {
      final bets = const CrowdBettor().betsFor(
        _view(<Tip>[_tip(id: 0, selection: Selection.home)]),
        4,
        _rng,
      );
      expect(bets.single.stake, 4);
    });

    test('stops when it is broke', () {
      expect(
        const CrowdBettor().betsFor(
          _view(<Tip>[_tip(id: 0, selection: Selection.home)]),
          0,
          _rng,
        ),
        isEmpty,
      );
    });
  });

  group('InsiderBettor', () {
    const insider = InsiderBettor(tipsterId: 2);

    test('takes its tipster and ignores everyone else', () {
      final bets = insider.betsFor(
        _view(<Tip>[
          _tip(id: 0, selection: Selection.home, believed: 0.99),
          _tip(id: 2, selection: Selection.away),
          _tip(id: 3, selection: Selection.draw, believed: 0.99),
        ]),
        1000,
        _rng,
      );
      expect(bets.single.selection, Selection.away);
    });

    test('passes when their edge is too thin', () {
      // Refusing a thin price is most of what separates a winning strategy
      // from a losing one.
      final bets = insider.betsFor(
        _view(<Tip>[_tip(id: 2, selection: Selection.home, believed: 0.5)]),
        1000,
        _rng,
      );
      expect(bets, isEmpty);
    });

    test('sits out when their tipster said nothing', () {
      expect(
        insider.betsFor(
          _view(<Tip>[_tip(id: 9, selection: Selection.home, believed: 0.99)]),
          1000,
          _rng,
        ),
        isEmpty,
      );
      expect(insider.betsFor(_view(<Tip>[]), 1000, _rng), isEmpty);
    });

    test('respects the market limit', () {
      final bets = insider.betsFor(
        _view(<Tip>[_tip(id: 2, selection: Selection.home, believed: 0.95)]),
        1000000,
        _rng,
      );
      expect(bets.single.stake, _market().limit);
    });

    test('stops when it is broke', () {
      expect(
        insider.betsFor(
          _view(<Tip>[_tip(id: 2, selection: Selection.home, believed: 0.95)]),
          0,
          _rng,
        ),
        isEmpty,
      );
    });
  });

  group('Tip', () {
    test('measures its edge against the de-vigged price', () {
      final market = _market();
      final tip = _tip(id: 0, selection: Selection.home);
      expect(
        tip.edgeAgainst(market),
        closeTo(0.6 - market.fairProbabilities[0], 1e-12),
      );
      expect(tip.toString(), '@t0: home');
    });
  });
}
