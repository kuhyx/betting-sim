import 'dart:math';

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
    this.maxStake = double.infinity,
    this.restricted = false,
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

  /// The largest stake the book will take. Bigger chips are greyed out.
  final double maxStake;

  /// Whether the book has cut this player's limits, which earns a note.
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tokens.inkRaised1,
      padding: const EdgeInsets.all(Tokens.space3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (restricted)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space2),
              child: Text(
                'limits cut to ${maxStake.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Tokens.mutedOnDark),
              ),
            ),
          _row(),
        ],
      ),
    );
  }

  Widget _row() {
    return Row(
      children: <Widget>[
        for (final size in <double>[5, 10, 25, 50]) ...<Widget>[
          _StakeChip(
            size: size,
            // The stake that actually goes on: a cut limit clamps the pick.
            selected: size == min(stakeSize, maxStake),
            onTap: size > maxStake ? null : () => onStakeChanged(size),
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
    );
  }
}

class _StakeChip extends StatelessWidget {
  const new({required this.size, required this.selected, required this.onTap});

  final double size;
  final bool selected;
  final VoidCallback? onTap;

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
            color: onTap == null
                ? Tokens.lineDark
                : selected
                ? Tokens.onFill
                : Tokens.mutedOnDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
