import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/ledger.dart';
import 'package:league_engine/league_engine.dart';

/// Everything you keep track of about other people.
///
/// The tipsters and the friends are the same idea wearing different clothes:
/// a cast fixed for the save, generated from the seed tree, whose usefulness
/// the game refuses to tell you. Both are only knowable by writing down what
/// they did and checking later, so both live here, next to the notebooks.
///
/// None of it is stored in a save. Restoring replays every matchday, and
/// every matchday folds its results back in.
class Records {
  /// Creates the cast for [masterSeed], loyal to clubs from [clubIds].
  Records({required this.masterSeed, required List<int> clubIds})
    : tipsters = generateTipsters(masterSeed),
      friends = generateFriends(masterSeed, clubIds);

  /// The save's root seed.
  final int masterSeed;

  /// The people posting about this league. Never labelled: which two of them
  /// are worth reading is the thing to find out.
  final List<Tipster> tipsters;

  /// The people you know who fancy a bet.
  final List<Friend> friends;

  /// What you have written down about the tipsters.
  final TipsterLedger ledger = TipsterLedger();

  /// Where each friendship stands, in money.
  final FriendBook friendBook = FriendBook();

  /// The proposals on the table right now.
  final PeerSlip peers = PeerSlip();

  /// Folds a played fixture into every notebook, and returns the friend bets
  /// it settled so the caller can move the money.
  List<PeerBet> settle(FixtureCard card, MatchResult result) {
    ledger.record(card.tips, result, card.market);
    final peerBets = peers.settleAll(card, result)..forEach(friendBook.add);
    return peerBets;
  }

  /// Forgets this matchday's undecided proposals.
  void nextDay() => peers.clear();
}
