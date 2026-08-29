import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/performance.dart';

/// The money, and everything it has done.
///
/// Three streams feed it and they are kept apart on purpose: bets against the
/// book, bets against friends, and the wages and rent of an ordinary week. A
/// save stores each separately and derives the balance, so no two of them can
/// quietly disagree about how much you have.
class Purse {
  /// Creates a purse holding [opening].
  Purse({this.opening = 1000}) : _bankroll = opening;

  /// What every game starts with.
  final double opening;

  /// The player's running ROI and CLV against the book.
  final Performance performance = Performance();

  final List<PlayerBet> _bets = <PlayerBet>[];
  final List<PeerBet> _peerBets = <PeerBet>[];
  double _bankroll;

  /// What is in the account.
  double get bankroll => _bankroll;

  /// Every settled bet against the book, most recent first.
  List<PlayerBet> get bets => List.unmodifiable(_bets.reversed);

  /// Every settled bet against a friend, most recent first.
  List<PeerBet> get peerBets => List.unmodifiable(_peerBets.reversed);

  /// Moves money without recording a bet: wages, rent, dinner, shopping.
  void adjust(double amount) => _bankroll += amount;

  /// Records a settled bet against the book.
  void take(PlayerBet bet) {
    _bankroll += bet.profit;
    performance.record(
      stake: bet.stake,
      profit: bet.profit,
      clv: bet.closingLineValue,
    );
    _bets.add(bet);
  }

  /// Records a settled bet against a friend.
  ///
  /// Deliberately NOT folded into [performance]: ROI and CLV are measured
  /// against a bookmaker's prices, and a handshake has neither a margin nor a
  /// closing line to measure against.
  void takePeer(PeerBet bet) {
    _bankroll += bet.profit;
    _peerBets.add(bet);
  }
}
