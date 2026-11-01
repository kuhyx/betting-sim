import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// How you are holding up: three bars side by side in one short strip.
class NeedsBars extends StatelessWidget {
  /// Creates the bars.
  const new({required this.needs, super.key});

  /// The three things that run down.
  final Needs needs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Bar(label: 'energy', value: needs.energy, goodHigh: true),
        ),
        const SizedBox(width: Tokens.space3),
        Expanded(
          child: _Bar(label: 'fed', value: needs.fullness, goodHigh: true),
        ),
        const SizedBox(width: Tokens.space3),
        Expanded(
          child: _Bar(label: 'stress', value: needs.stress, goodHigh: false),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.label, required this.value, required this.goodHigh});

  final String label;
  final double value;
  final bool goodHigh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final healthy = goodHigh ? value > 0.3 : value < 0.7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
              ),
            ),
            Text('${(value * 100).round()}%', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: Tokens.space1),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Tokens.lineDark,
          color: healthy ? Tokens.success : Tokens.danger,
        ),
      ],
    );
  }
}
