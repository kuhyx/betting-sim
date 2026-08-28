import 'package:betting_sim/state/performance.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// Running ROI and CLV: enough to judge whether a setting is winnable.
///
/// Both are shown because they answer different questions. ROI is the outcome
/// and is mostly variance over a short session; CLV compares prices and is
/// readable far sooner.
class Scoreboard extends StatelessWidget {
  /// Creates a scoreboard.
  const Scoreboard({required this.performance, super.key});

  /// The player's running scoreboard.
  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final roi = performance.roi;
    final clv = performance.averageClv;
    final beat = performance.beatRate;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _Stat(
          label: 'ROI',
          value: roi == null ? '--' : _percent(roi),
          tone: _toneOf(roi),
        ),
        _Stat(
          label: 'CLV',
          value: clv == null ? '--' : _percent(clv),
          tone: _toneOf(clv),
        ),
        _Stat(
          label: 'beat rate',
          value: beat == null ? '--' : _percent(beat, signed: false),
          tone: Tokens.textOnDark,
        ),
        _Stat(
          label: 'bets',
          value: '${performance.bets}',
          tone: Tokens.textOnDark,
        ),
      ],
    );
  }

  static String _percent(double v, {bool signed = true}) {
    final pct = (v * 100).toStringAsFixed(2);
    return signed && v >= 0 ? '+$pct%' : '$pct%';
  }

  static Color _toneOf(double? v) {
    if (v == null) {
      return Tokens.mutedOnDark;
    }
    return v >= 0 ? Tokens.success : Tokens.danger;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Tokens.mutedOnDark, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: tone,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
