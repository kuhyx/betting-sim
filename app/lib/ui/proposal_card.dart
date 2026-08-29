import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// One friend's offer, and the three things you can do about it.
class ProposalCard extends StatelessWidget {
  /// Creates the card.
  const ProposalCard({
    required this.terms,
    required this.fixture,
    required this.outcome,
    required this.onAccept,
    required this.onHaggle,
    required this.onReject,
    super.key,
  });

  /// What was offered. The walk-away price inside is never shown.
  final ProposalTerms terms;

  /// Which match, as text.
  final String fixture;

  /// What you already did about it, if anything.
  final String? outcome;

  /// Take it as offered.
  final VoidCallback onAccept;

  /// Ask for a better price, and risk them walking.
  final VoidCallback onHaggle;

  /// Turn it down.
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = terms.proposal;
    final decided = outcome != null;

    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      padding: const EdgeInsets.all(Tokens.space4),
      color: Tokens.inkRaised1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  p.name,
                  style: text.bodyMedium?.copyWith(color: Tokens.accent),
                ),
              ),
              Text(
                fixture,
                style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space2),
          Text('"${p.message}"', style: text.bodySmall),
          const SizedBox(height: Tokens.space2),
          Text(
            'they want ${p.selection.name} at '
            '${p.odds.decimal.toStringAsFixed(2)} for '
            '${p.stake.toStringAsFixed(0)}',
            style: text.bodySmall,
          ),
          Text(
            'you risk ${p.atRisk.toStringAsFixed(0)} to win '
            '${p.stake.toStringAsFixed(0)}',
            style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
          ),
          const SizedBox(height: Tokens.space3),
          if (decided)
            Text(
              outcome!,
              style: text.bodySmall?.copyWith(color: Tokens.accent),
            )
          else
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: onAccept,
                  child: const Text(
                    "YOU'RE ON",
                    style: TextStyle(color: Tokens.success),
                  ),
                ),
                TextButton(
                  onPressed: onHaggle,
                  child: const Text(
                    'HAGGLE',
                    style: TextStyle(color: Tokens.accent),
                  ),
                ),
                TextButton(
                  onPressed: onReject,
                  child: const Text(
                    'LEAVE IT',
                    style: TextStyle(color: Tokens.mutedOnDark),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
