import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// How you are holding up.
class NeedsBars extends StatelessWidget {
  /// Creates the bars.
  const NeedsBars({required this.needs, super.key});

  /// The three things that run down.
  final Needs needs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Bar(label: 'energy', value: needs.energy, goodHigh: true),
        _Bar(label: 'fed', value: needs.fullness, goodHigh: true),
        _Bar(label: 'stress', value: needs.stress, goodHigh: false),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.goodHigh,
  });

  final String label;
  final double value;
  final bool goodHigh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final healthy = goodHigh ? value > 0.3 : value < 0.7;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Tokens.lineDark,
              color: healthy ? Tokens.success : Tokens.danger,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
