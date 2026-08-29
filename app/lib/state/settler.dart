import 'package:betting_sim/state/cards.dart';
import 'package:league_engine/league_engine.dart';

/// A fixture that has been played, kept so the player can watch it back.
///
/// Holds the CONTEXT and the RESULT rather than a narrated timeline: the
/// report is regenerated from the seed tree on demand, so watching a match
/// costs nothing until somebody actually opens it, and a save never has to
/// carry a box score.
class PlayedMatch {
  /// Creates a played match.
  const PlayedMatch({
    required this.home,
    required this.away,
    required this.context,
    required this.result,
  });

  /// The match [card] turned into, once [result] is known.
  factory PlayedMatch.of(FixtureCard card, MatchResult result) => PlayedMatch(
    home: card.home,
    away: card.away,
    context: card.context,
    result: result,
  );

  /// The home club.
  final Team home;

  /// The away club.
  final Team away;

  /// Everything the match was played from.
  final MatchContext context;

  /// What happened.
  final MatchResult result;

  /// The scoreline, as text.
  String get scoreline => '${result.homeScore}-${result.awayScore}';
}

/// Settles one staked selection against [result].
///
/// Pure: it works out what the bet was worth and what the price was worth,
/// and returns the record. Moving the money is the caller's job, which keeps
/// the arithmetic testable without a whole game around it.
PlayerBet settleCard({
  required FixtureCard card,
  required Selection selection,
  required double stake,
  required MatchResult result,
  ClvCalculator clv = const ClvCalculator(),
}) {
  final bet = Bet(
    selection: selection,
    stake: stake,
    taken: card.market.priceOf(selection),
  );
  return PlayerBet(
    fixture: '${card.home.name} v ${card.away.name}',
    selection: selection,
    stake: stake,
    taken: bet.taken,
    profit: settle(bet, result),
    result: '${result.homeScore}-${result.awayScore}',
    closingLineValue: clv.forBet(
      selection: selection,
      taken: bet.taken,
      closing: card.closing,
    ),
  );
}
