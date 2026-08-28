import 'package:betting_sim/state/performance.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:betting_sim/ui/scoreboard.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// The title of the debug tuning surface.
///
/// Named as a constant because it doubles as the canary the release-build
/// check greps for: `scripts/check_debug_absent.sh` asserts this exact string
/// is present in a debug web build and absent from a release one. A UI-only
/// string is the right canary -- an engine field name like
/// `bookLatentAwareness` ships in release regardless.
const debugPanelTitle = 'BALANCE TUNING (debug only)';

/// A debug-only surface for the balance knobs, with the feedback needed to
/// judge them.
///
/// Never shown in a release build. The gate is [DebugTuningPanel.enabled],
/// injected rather than read from `kDebugMode` here so tests can drive both
/// states; the single real `kDebugMode` read is in `main.dart`.
class DebugTuningPanel extends StatelessWidget {
  /// Creates the panel.
  const DebugTuningPanel({
    required this.tuning,
    required this.performance,
    required this.onChanged,
    this.enabled = false,
    super.key,
  });

  /// The knobs as they currently stand.
  final Tuning tuning;

  /// The player's running scoreboard.
  final Performance performance;

  /// Called with the new tuning. Restarts the season: pricing has changed.
  final ValueChanged<Tuning> onChanged;

  /// Whether the panel may be shown at all.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: Tokens.inkRaised2,
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            debugPanelTitle,
            style: TextStyle(
              color: Tokens.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Tokens.space1),
          const Text(
            'changing a knob restarts the season: it changes pricing',
            style: TextStyle(color: Tokens.mutedOnDark, fontSize: 11),
          ),
          const SizedBox(height: Tokens.space3),
          Scoreboard(performance: performance),
          const SizedBox(height: Tokens.space3),
          _Knob(
            label: 'book awareness',
            value: tuning.bookLatentAwareness,
            min: 0,
            max: 1,
            digits: 2,
            onChanged: (v) => onChanged(
              tuning.copyWith(
                bookLatentAwareness: v,
              ),
            ),
          ),
          _Knob(
            label: 'margin',
            value: tuning.margin,
            min: 0,
            max: 0.15,
            digits: 3,
            onChanged: (v) => onChanged(tuning.copyWith(margin: v)),
          ),
          _Knob(
            label: 'strength scale',
            value: tuning.strengthScale,
            min: 0,
            max: 0.02,
            digits: 4,
            onChanged: (v) => onChanged(tuning.copyWith(strengthScale: v)),
          ),
          _Knob(
            label: 'fatigue penalty',
            value: tuning.fatigueAttackPenalty,
            min: 0,
            max: 0.5,
            digits: 2,
            onChanged: (v) => onChanged(
              tuning.copyWith(
                fatigueAttackPenalty: v,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Knob extends StatelessWidget {
  const _Knob({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.digits,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int digits;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Tokens.mutedOnDark, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            value.toStringAsFixed(digits),
            style: const TextStyle(
              color: Tokens.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: Tokens.accent,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
