/// How much the book will let someone stake.
///
/// Two mechanisms, both drawn from how real books behave:
///
///  * A market's limit RISES as it sharpens. An opening line is a guess, so
///    the book risks little on it; by kick-off it is confident and takes more.
///  * A WINNING player's limit falls. Books restrict and eventually ban
///    bettors who beat the closing line, which is the single most important
///    fact about professional betting -- and here it is the antagonist, and
///    the reason grinding a known edge forever is not the game.
class LimitPolicy {
  /// Creates a limit policy.
  const LimitPolicy({
    this.openingLimit = 50,
    this.closingLimit = 500,
    this.restrictionThreshold = 0.02,
    this.minimumLimit = 5,
    this.restrictionSeverity = 8,
  });

  /// The stake accepted when a market opens.
  final double openingLimit;

  /// The stake accepted once the line has fully sharpened.
  final double closingLimit;

  /// The average CLV above which the book starts restricting a player.
  ///
  /// 2% is the industry's own rule of thumb for a sharp bettor.
  final double restrictionThreshold;

  /// The floor a restricted player is cut to.
  final double minimumLimit;

  /// How aggressively limits fall once a player is flagged.
  final double restrictionSeverity;

  /// The limit for a market that is [sharpness] of the way to kick-off.
  double limitAt(double sharpness) {
    final t = sharpness.clamp(0.0, 1.0);
    return openingLimit + (closingLimit - openingLimit) * t;
  }

  /// The limit a player with average [closingLineValue] is allowed.
  ///
  /// A player at or below the threshold is unrestricted. Above it, the limit
  /// decays toward [minimumLimit] -- the book has noticed.
  double limitForPlayer(double baseLimit, double closingLineValue) {
    if (closingLineValue <= restrictionThreshold) {
      return baseLimit;
    }
    final excess = closingLineValue - restrictionThreshold;
    final factor = 1 / (1 + restrictionSeverity * excess * 10);
    final scaled = baseLimit * factor;
    return scaled < minimumLimit ? minimumLimit : scaled;
  }

  /// Whether the book has restricted this player at all.
  bool isRestricted(double closingLineValue) =>
      closingLineValue > restrictionThreshold;
}
