import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// A tappable price for one outcome.
///
/// Label on the left, price on the right, filling the box it is given: a
/// fixture tile stacks three of them, so a column of markets scans down the
/// price edge without re-reading which side is which.
class OddsButton extends StatelessWidget {
  /// Creates a price button.
  const new({
    required this.label,
    required this.odds,
    required this.format,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Which outcome, e.g. the home club's short name.
  final String label;

  /// The price.
  final Odds odds;

  /// How to render it.
  final OddsFormat format;

  /// Whether this is the player's current pick on this fixture.
  final bool selected;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label at ${odds.format(format)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
          decoration: BoxDecoration(
            color: selected ? Tokens.accent : Tokens.inkRaised2,
            borderRadius: BorderRadius.circular(Tokens.radiusSmall),
            border: Border.all(
              color: selected ? Tokens.accent : Tokens.lineDark,
            ),
          ),
          // On a filled accent surface text must be ink, never near-white:
          // the shared rule, measured at 2.2-3.6:1 for near-white against
          // WCAG's 4.5:1 floor.
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? Tokens.onFill : Tokens.mutedOnDark,
                  ),
                ),
              ),
              Text(
                odds.format(format),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Tokens.onFill : Tokens.textOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
