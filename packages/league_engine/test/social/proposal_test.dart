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

Friend _friend(FriendBias bias) => Friend(
  id: 0,
  name: 'Mate',
  awareness: 0,
  noise: 0,
  bias: bias,
  loyalClubId: 1,
  chattiness: 1,
  stubbornness: 0,
);

void main() {
  group('FriendProposal', () {
    const proposal = FriendProposal(
      friendId: 3,
      name: 'Mate',
      selection: Selection.home,
      stake: 20,
      odds: Odds(3),
      message: 'go on then',
    );

    test('describes what you are actually risking', () {
      expect(proposal.atRisk, 40);
      expect(proposal.toString(), contains('home @ 3.00 for 20.0'));
    });

    test('can be struck at another price', () {
      final moved = proposal.at(const Odds(2));
      expect(moved.odds.decimal, 2);
      expect(moved.atRisk, 20);
      expect(moved.name, proposal.name);
      expect(moved.selection, proposal.selection);
      expect(moved.message, proposal.message);
      expect(moved.friendId, proposal.friendId);
    });

    test('pays you their stake when their pick loses', () {
      const theyWin = MatchResult(
        homeScore: 2,
        awayScore: 0,
        events: <MatchEvent>[],
      );
      const theyLose = MatchResult(
        homeScore: 0,
        awayScore: 2,
        events: <MatchEvent>[],
      );
      const drawn = MatchResult(
        homeScore: 1,
        awayScore: 1,
        events: <MatchEvent>[],
      );
      expect(settleProposal(proposal, theyWin), -40);
      expect(settleProposal(proposal, theyLose), 20);
      expect(settleProposal(proposal, drawn), 20);

      const onTheDraw = FriendProposal(
        friendId: 0,
        name: 'M',
        selection: Selection.draw,
        stake: 10,
        odds: Odds(4),
        message: '',
      );
      expect(settleProposal(onTheDraw, drawn), -30);
      expect(settleProposal(onTheDraw, theyWin), 10);

      const onTheAway = FriendProposal(
        friendId: 0,
        name: 'M',
        selection: Selection.away,
        stake: 10,
        odds: Odds(4),
        message: '',
      );
      expect(settleProposal(onTheAway, theyLose), -30);
      expect(settleProposal(onTheAway, theyWin), 10);
    });
  });

  group('writeProposal', () {
    test('writes to the bias, for every side', () {
      for (final bias in FriendBias.values) {
        for (final selection in Selection.values) {
          for (var seed = 0; seed < 8; seed++) {
            final text = writeProposal(
              friend: _friend(bias),
              selection: selection,
              home: _club(1, 'Ashcombe'),
              away: _club(2, 'Draymoor'),
              stake: 25,
              rng: Mix32Source(seed),
            );
            expect(text, contains('25 on'));
            expect(text.trim(), isNotEmpty);
          }
        }
      }
    });
  });
}
