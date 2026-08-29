import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

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

BettingView _view() => BettingView(
  market: const Bookmaker().price(
    const OutcomeProbs(home: 0.45, draw: 0.28, away: 0.27),
  ),
  context: MatchContext(
    home: _club(1),
    away: _club(2),
    homeModifiers: const MatchModifiers(),
    awayModifiers: const MatchModifiers(),
    seedPath: const SeedPath(master: 1),
  ),
);

FriendProposal _proposal(Odds odds, {Selection selection = Selection.home}) =>
    FriendProposal(
      friendId: 0,
      name: 'Mate',
      selection: selection,
      stake: 20,
      odds: odds,
      message: '',
    );

void main() {
  group('AcceptAllReviewer', () {
    test('says yes to anything at all', () {
      const reviewer = AcceptAllReviewer();
      expect(reviewer.name, 'accept-all');
      expect(
        reviewer.review(_proposal(const Odds(1.01)), _view()).accepted,
        isTrue,
      );
      expect(
        reviewer.review(_proposal(const Odds(50)), _view()).accepted,
        isTrue,
      );
    });
  });

  group('ShrewdReviewer', () {
    const reviewer = ShrewdReviewer();

    // The market makes the home side about 45%, so laying it is worth
    // `1 - 0.45 * odds` per unit of their stake -- which FALLS as the price
    // rises. A layer wants a SHORT price, which is the opposite of the
    // instinct a backer has.

    test('takes a price that is clearly too short', () {
      final decision = reviewer.review(_proposal(const Odds(1.8)), _view());
      expect(decision.accepted, isTrue);
      expect(decision.counter, isNull);
      expect(reviewer.name, 'shrewd');
    });

    test('haggles when the price is close but not close enough', () {
      final decision = reviewer.review(_proposal(const Odds(2.5)), _view());
      expect(decision.accepted, isFalse);
      expect(decision.counter, isNotNull);
      // A counter always asks for a SHORTER price.
      expect(decision.counter!.decimal, lessThan(2.5));
    });

    test('will not counter to a price it would itself have refused', () {
      // Only reachable if somebody configures the counter to aim LOWER than
      // the acceptance bar, which would talk the reviewer into a bet it had
      // just turned down. The guard says nothing rather than doing that.
      const muddled = ShrewdReviewer(edgeThreshold: 0.2, counterAtEdge: 0.01);
      final decision = muddled.review(_proposal(const Odds(2.1)), _view());
      expect(decision.accepted, isFalse);
      expect(decision.counter, isNull);
    });

    test('walks away when nothing could make it worth taking', () {
      // Laying a near-certainty: they would have to pay YOU to take it on.
      final decision = reviewer.review(
        _proposal(const Odds(1.02)),
        BettingView(
          market: const Bookmaker().price(
            const OutcomeProbs(home: 0.97, draw: 0.02, away: 0.01),
          ),
          context: _view().context,
        ),
      );
      expect(decision.accepted, isFalse);
      expect(decision.counter, isNull);
    });
  });

  group('SocialSeasonRunner', () {
    const runner = SocialSeasonRunner();

    test('plays a whole season of handshakes', () {
      final season = runner.run(
        masterSeed: 4242,
        reviewer: const AcceptAllReviewer(),
      );
      expect(season.bettorName, 'accept-all');
      expect(season.matchdays, hasLength(38));
      expect(season.bets, isNotEmpty);
      expect(season.staked, greaterThan(0));
      // There is no closing line on a handshake.
      expect(season.bets.every((b) => b.closingLineValue == 0), isTrue);
    });

    test('replays exactly', () {
      final once = runner.run(
        masterSeed: 4242,
        reviewer: const ShrewdReviewer(),
      );
      final twice = runner.run(
        masterSeed: 4242,
        reviewer: const ShrewdReviewer(),
      );
      expect(twice.profit, once.profit);
      expect(twice.bets.length, once.bets.length);
    });

    test('a reviewer that says no to everything strikes nothing', () {
      final season = runner.run(
        masterSeed: 4242,
        reviewer: const _NeverReviewer(),
      );
      expect(season.bets, isEmpty);
      expect(season.staked, 0);
    });

    test('a counter is struck only when they would shake on it', () {
      // Countering at a price nobody would take must leave no bet behind.
      final greedy = runner.run(
        masterSeed: 4242,
        reviewer: const _CounterReviewer(Odds(1.01)),
      );
      expect(greedy.bets, isEmpty);

      // Countering at a price everybody takes must strike every time.
      final generous = runner.run(
        masterSeed: 4242,
        reviewer: const _CounterReviewer(Odds(100)),
      );
      expect(generous.bets, isNotEmpty);
      expect(
        generous.bets.every((b) => b.bet.taken.decimal < 1.02),
        isTrue,
        reason: 'laying at 100 means risking a lot to win a little',
      );
    });

    test('choosing beats accepting over a season', () {
      final lazy = <SeasonResult>[
        for (var i = 0; i < 8; i++)
          runner.run(masterSeed: 100 + i, reviewer: const AcceptAllReviewer()),
      ];
      final picky = <SeasonResult>[
        for (var i = 0; i < 8; i++)
          runner.run(masterSeed: 100 + i, reviewer: const ShrewdReviewer()),
      ];
      expect(
        summarise('shrewd', picky).meanSeasonRoi,
        greaterThan(summarise('accept-all', lazy).meanSeasonRoi),
      );
    });
  });
}

class _NeverReviewer implements ProposalReviewer {
  const _NeverReviewer();

  @override
  String get name => 'never';

  @override
  ProposalDecision review(FriendProposal proposal, BettingView view) =>
      const ProposalDecision.reject();
}

class _CounterReviewer implements ProposalReviewer {
  const _CounterReviewer(this.at);

  final Odds at;

  @override
  String get name => 'counter';

  @override
  ProposalDecision review(FriendProposal proposal, BettingView view) =>
      ProposalDecision.counterAt(at);
}
