import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// A tappable price for one outcome.
///
/// Shows the label above the price so the eye can scan a column of markets
/// without re-reading which side is which.
class OddsButton extends StatelessWidget {
  /// Creates a price button.
  const OddsButton({
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
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label at ${odds.format(format)}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Tokens.radiusSmall),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: Tokens.space2,
              horizontal: Tokens.space1,
            ),
            decoration: BoxDecoration(
              color: selected ? Tokens.accent : Tokens.inkRaised2,
              borderRadius: BorderRadius.circular(Tokens.radiusSmall),
              border: Border.all(
                color: selected ? Tokens.accent : Tokens.lineDark,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    // On a filled accent surface text must be ink, never
                    // near-white: the shared rule, measured at 2.2-3.6:1 for
                    // near-white against WCAG's 4.5:1 floor.
                    color: selected ? Tokens.onFill : Tokens.mutedOnDark,
                  ),
                ),
                const SizedBox(height: Tokens.space1),
                Text(
                  odds.format(format),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected ? Tokens.onFill : Tokens.textOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
