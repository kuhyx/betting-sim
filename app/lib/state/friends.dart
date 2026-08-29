import 'package:betting_sim/state/cards.dart';
import 'package:league_engine/league_engine.dart';

/// A friend bet you struck, once it has settled.
class PeerBet {
  /// Creates a settled peer bet.
  const PeerBet({
    required this.friendId,
    required this.name,
    required this.fixture,
    required this.selection,
    required this.stake,
    required this.odds,
    required this.profit,
    required this.result,
    required this.haggled,
  });

  /// Whose bet it was.
  final int friendId;

  /// What you call them.
  final String name;

  /// Which match.
  final String fixture;

  /// What THEY backed. You were on the other side.
  final Selection selection;

  /// What they put up, which is what you stood to win.
  final double stake;

  /// The price it was struck at.
  final Odds odds;

  /// What it made you, negative for a loss.
  final double profit;

  /// The final score.
  final String result;

  /// Whether you talked them down first.
  final bool haggled;

  /// What you had at risk.
  double get atRisk => stake * odds.profit;
}

/// Where each friendship stands, in money.
class FriendBook {
  /// An empty book.
  FriendBook();

  final Map<int, double> _balances = <int, double>{};
  final Map<int, int> _counts = <int, int>{};

  /// What [friendId] has cost you, or made you, over the season.
  double balanceWith(int friendId) => _balances[friendId] ?? 0;

  /// How many bets you have struck with them.
  int betsWith(int friendId) => _counts[friendId] ?? 0;

  /// Everyone you have a running total with, biggest winner for you first.
  List<({int friendId, double balance, int bets})> get standings {
    return <({int friendId, double balance, int bets})>[
      for (final e in _balances.entries)
        (friendId: e.key, balance: e.value, bets: betsWith(e.key)),
    ]..sort((a, b) {
      final byBalance = b.balance.compareTo(a.balance);
      return byBalance != 0 ? byBalance : a.friendId.compareTo(b.friendId);
    });
  }

  /// Folds a settled bet in.
  void add(PeerBet bet) {
    _balances[bet.friendId] = balanceWith(bet.friendId) + bet.profit;
    _counts[bet.friendId] = betsWith(bet.friendId) + 1;
  }
}

/// The proposals on the table right now, and what you have said about them.
///
/// The mirror of the bet slip, and deliberately as thin: a decision is only a
/// decision until the matchday is played, at which point it becomes money and
/// moves to the book.
class PeerSlip {
  /// An empty table.
  PeerSlip();

  /// How much of a friend's asking price a haggle tries to take off.
  ///
  /// A real decision rather than a free reroll: countering can lose you a bet
  /// you would have been perfectly happy with, because a stubborn friend
  /// simply walks.
  static const double haggleFactor = 0.85;

  final Map<int, FriendProposal> _struck = <int, FriendProposal>{};
  final Set<int> _settledOn = <int>{};

  /// A stable key for one proposal on one fixture.
  static int keyFor(int fixtureIndex, int proposalIndex) =>
      fixtureIndex * 100 + proposalIndex;

  /// The bet struck on this proposal, if any.
  FriendProposal? struckOn(int fixtureIndex, int proposalIndex) =>
      _struck[keyFor(fixtureIndex, proposalIndex)];

  /// Whether this proposal has been dealt with, either way.
  bool settled(int fixtureIndex, int proposalIndex) =>
      _settledOn.contains(keyFor(fixtureIndex, proposalIndex));

  /// How many bets are on the table.
  int get count => _struck.length;

  /// Total at risk across everything struck.
  double get atRisk => _struck.values.fold(0, (sum, p) => sum + p.atRisk);

  /// Takes a proposal at its asking price.
  void accept(int fixtureIndex, int proposalIndex, FriendProposal proposal) {
    final key = keyFor(fixtureIndex, proposalIndex);
    _struck[key] = proposal;
    _settledOn.add(key);
  }

  /// Turns one down.
  void reject(int fixtureIndex, int proposalIndex) =>
      _settledOn.add(keyFor(fixtureIndex, proposalIndex));

  /// Asks for a better price. Returns whether they shook on it.
  ///
  /// Either way the proposal is off the table: a friend who has been talked
  /// down does not then let you think about it, and one who walks does not
  /// come back.
  bool haggle(int fixtureIndex, int proposalIndex, ProposalTerms terms) {
    final wanted = Odds(1 + terms.proposal.odds.profit * haggleFactor);
    final shook = terms.wouldAccept(wanted);
    if (shook) {
      accept(fixtureIndex, proposalIndex, terms.proposal.at(wanted));
    } else {
      reject(fixtureIndex, proposalIndex);
    }
    return shook;
  }

  /// Settles everything struck on [card] against [result], and clears it.
  List<PeerBet> settleAll(FixtureCard card, MatchResult result) {
    final settled = <PeerBet>[];
    for (var i = 0; i < card.proposals.length; i++) {
      final struck = _struck.remove(keyFor(card.index, i));
      if (struck == null) {
        continue;
      }
      settled.add(
        PeerBet(
          friendId: struck.friendId,
          name: struck.name,
          fixture: '${card.home.name} v ${card.away.name}',
          selection: struck.selection,
          stake: struck.stake,
          odds: struck.odds,
          profit: settleProposal(struck, result),
          result: '${result.homeScore}-${result.awayScore}',
          haggled:
              struck.odds.decimal != card.proposals[i].proposal.odds.decimal,
        ),
      );
    }
    return settled;
  }

  /// Forgets every decision, for the next matchday.
  void clear() {
    _struck.clear();
    _settledOn.clear();
  }
}
