import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// The stake picker and the settle button.
class ActionBar extends StatelessWidget {
  /// Creates the action bar.
  const new({
    required this.stakeSize,
    required this.onStakeChanged,
    required this.onSettle,
    required this.hasBets,
    super.key,
  });

  /// The currently selected stake.
  final double stakeSize;

  /// Called when the player picks a different stake.
  final ValueChanged<double> onStakeChanged;

  /// Called when the player plays the matchday.
  final VoidCallback onSettle;

  /// Whether anything is on the slip.
  final bool hasBets;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tokens.inkRaised1,
      padding: const EdgeInsets.all(Tokens.space3),
      child: Row(
        children: <Widget>[
          for (final size in <double>[5, 10, 25, 50]) ...<Widget>[
            _StakeChip(
              size: size,
              selected: stakeSize == size,
              onTap: () => onStakeChanged(size),
            ),
            const SizedBox(width: Tokens.space2),
          ],
          // Scaled down rather than wrapped: on a phone the four stakes and
          // the longer label do not share one row at full size.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: FilledButton(
                  onPressed: onSettle,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.accent,
                    foregroundColor: Tokens.onFill,
                  ),
                  child: Text(hasBets ? 'PLAY MATCHDAY' : 'SKIP MATCHDAY'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StakeChip extends StatelessWidget {
  const new({required this.size, required this.selected, required this.onTap});

  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space2 + Tokens.space1,
          vertical: Tokens.space2,
        ),
        decoration: BoxDecoration(
          color: selected ? Tokens.accent : Tokens.inkRaised2,
          borderRadius: BorderRadius.circular(Tokens.radiusSmall),
          border: Border.all(color: selected ? Tokens.accent : Tokens.lineDark),
        ),
        child: Text(
          size.toStringAsFixed(0),
          style: TextStyle(
            color: selected ? Tokens.onFill : Tokens.mutedOnDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
