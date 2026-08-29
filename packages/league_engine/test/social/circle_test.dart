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

MatchContext _ctx({int seed = 77}) => MatchContext(
  home: _club(1, 'Home'),
  away: _club(2, 'Away'),
  homeModifiers: const MatchModifiers(attackMultiplier: 0.85),
  awayModifiers: const MatchModifiers(),
  seedPath: SeedPath(master: seed, season: 0, day: 0, match: 0),
);

Market _market() => const Bookmaker().price(
  const DixonColesModel().outcomeProbabilities(_ctx().latentBlind),
);

Friend _friend({
  required FriendBias bias,
  double chattiness = 1,
  double stubbornness = 0,
  double noise = 0,
  double awareness = 0,
  int loyalClubId = 1,
}) => Friend(
  id: 0,
  name: 'Mate',
  awareness: awareness,
  noise: noise,
  bias: bias,
  loyalClubId: loyalClubId,
  chattiness: chattiness,
  stubbornness: stubbornness,
);

void main() {
  const circle = FriendCircle();
  final market = _market();

  List<ProposalTerms> proposals(List<Friend> friends, {int seed = 77}) =>
      circle.proposalsFor(
        ctx: _ctx(seed: seed),
        path: SeedPath(master: seed, season: 0, day: 0, match: 0),
        friends: friends,
        market: market,
      );

  group('FriendCircle', () {
    test('everybody talkative says something', () {
      final terms = proposals(<Friend>[
        _friend(bias: FriendBias.chalk),
        _friend(bias: FriendBias.chalk),
        _friend(bias: FriendBias.chalk),
      ]);
      expect(terms, hasLength(3));
      expect(terms.every((t) => t.proposal.message.isNotEmpty), isTrue);
      expect(terms.every((t) => t.proposal.stake >= 5), isTrue);
      expect(terms.every((t) => t.proposal.stake <= 40), isTrue);
    });

    test('nobody quiet says anything', () {
      expect(
        proposals(<Friend>[_friend(bias: FriendBias.chalk, chattiness: 0)]),
        isEmpty,
      );
    });

    test('somebody going quiet does not change what the next one says', () {
      // Every friend rolls in a fixed order whether or not they speak, so a
      // silent friend cannot shift the stream under the people after them.
      final loud = proposals(<Friend>[
        _friend(bias: FriendBias.chalk),
        _friend(bias: FriendBias.cagey),
      ]);
      final quieter = proposals(<Friend>[
        _friend(bias: FriendBias.chalk, chattiness: 0),
        _friend(bias: FriendBias.cagey),
      ]);
      expect(quieter.single.proposal.stake, loud.last.proposal.stake);
      expect(
        quieter.single.proposal.odds.decimal,
        loud.last.proposal.odds.decimal,
      );
    });

    test('each sort of friend wants the thing they always want', () {
      final fair = market.fairProbabilities;
      final favourite = favouriteOf(
        OutcomeProbs(home: fair[0], draw: fair[1], away: fair[2]),
      );

      Selection wants(Friend friend) =>
          proposals(<Friend>[friend]).single.proposal.selection;

      expect(wants(_friend(bias: FriendBias.cagey)), Selection.draw);
      expect(wants(_friend(bias: FriendBias.chalk)), favourite);
      expect(
        wants(_friend(bias: FriendBias.longshot)),
        isNot(favourite),
      );
      expect(wants(_friend(bias: FriendBias.loyal)), Selection.home);
      expect(
        wants(_friend(bias: FriendBias.loyal, loyalClubId: 2)),
        Selection.away,
      );
      // Their club is not playing, so they revert to type.
      expect(
        wants(_friend(bias: FriendBias.loyal, loyalClubId: 99)),
        favourite,
      );
    });

    test('asks a price that is fair by their own lights', () {
      // No margin. A friend is not a smaller bookmaker, which is why saying
      // yes to everything is close to a coin flip rather than a slow bleed.
      final terms = proposals(<Friend>[_friend(bias: FriendBias.chalk)]).single;
      final believed = 1 / terms.proposal.odds.decimal;
      expect(believed, greaterThan(0));
      expect(believed, lessThan(1));
      expect(
        terms.proposal.atRisk,
        closeTo(terms.proposal.stake * terms.proposal.odds.profit, 1e-9),
      );
    });

    test('a stubborn friend will not move, a soft one will', () {
      final firm = proposals(<Friend>[_friend(bias: FriendBias.chalk)]).single;
      expect(firm.wouldAccept(firm.proposal.odds), isTrue);
      expect(firm.wouldAccept(const Odds(1.01)), isFalse);

      final soft = proposals(<Friend>[
        _friend(bias: FriendBias.chalk, stubbornness: 0.6),
      ]).single;
      final halfway = Odds(1 + soft.proposal.odds.profit * 0.5);
      expect(soft.wouldAccept(halfway), isTrue);
    });

    test('replays exactly from the same address', () {
      final friends = <Friend>[
        _friend(bias: FriendBias.chalk),
        _friend(bias: FriendBias.longshot),
      ];
      expect(
        proposals(friends).map((t) => t.proposal.toString()),
        proposals(friends).map((t) => t.proposal.toString()),
      );
    });
  });
}
