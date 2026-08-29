import 'package:league_engine/league_engine.dart';

/// A fixture as the player sees it: the two clubs and the prices on offer.
class FixtureCard {
  /// Creates a fixture card.
  const FixtureCard({
    required this.home,
    required this.away,
    required this.market,
    required this.closing,
    required this.context,
    required this.index,
    this.tips = const <Tip>[],
    this.proposals = const <ProposalTerms>[],
  });

  /// The home club.
  final Team home;

  /// The away club.
  final Team away;

  /// The prices the player may bet into.
  final Market market;

  /// Where the line closes.
  ///
  /// Retained rather than discarded because CLV -- the game's real scoreboard
  /// -- is measured against it. The player never sees it before settling, so
  /// holding it here leaks nothing: it is written at pricing time and read
  /// only once the match has been played.
  final Market closing;

  /// Everything needed to play the match.
  final MatchContext context;

  /// Which fixture on the matchday this is.
  final int index;

  /// What the internet is saying about it.
  ///
  /// Generated from the seed tree like everything else -- the sport, the
  /// clubs and the money are invented, so the people arguing about them are
  /// too. There is no network call anywhere in this app.
  final List<Tip> tips;

  /// What your friends want on it, and the walk-away price you cannot see.
  ///
  /// The terms rather than the bare proposals: `ProposalTerms.floorOdds` is
  /// how the game knows whether a haggle lands, and it is never shown.
  final List<ProposalTerms> proposals;
}

/// A bet the player has struck, once settled.
class PlayerBet {
  /// Creates a settled player bet.
  const PlayerBet({
    required this.fixture,
    required this.selection,
    required this.stake,
    required this.taken,
    required this.profit,
    required this.result,
    required this.closingLineValue,
  });

  /// What was backed.
  final String fixture;

  /// Which outcome.
  final Selection selection;

  /// How much was staked.
  final double stake;

  /// The price taken.
  final Odds taken;

  /// Profit, negative for a loss.
  final double profit;

  /// The final score.
  final String result;

  /// How the price taken compared with the closing line.
  final double closingLineValue;

  /// Whether the bet won.
  bool get won => profit > 0;
}
