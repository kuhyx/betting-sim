import 'package:betting_sim/state/life.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// How you are spending today.
///
/// Named for hours rather than days because the engine already has a
/// `DayPlanner` -- that one decides a whole day for a control in the
/// acceptance gate, this one is the player deciding it an hour at a time.
///
/// A budget, not a calendar: the hours are the whole mechanic, because an
/// hour worked is an hour not spent reading the feed, and the rent does not
/// care which you picked.
class HourPlanner extends StatelessWidget {
  /// Creates the planner.
  const new({
    required this.life,
    required this.plan,
    required this.onAdd,
    required this.onClear,
    super.key,
  });

  /// The clock and the needs.
  final LifeState life;

  /// The hours allocated so far.
  final Map<Activity, int> plan;

  /// Adds an hour of something.
  final void Function(Activity) onAdd;

  /// Starts the day again.
  final VoidCallback onClear;

  /// How many hours are still going spare.
  int get spare =>
      life.hoursToday - plan.values.fold(0, (sum, hours) => sum + hours);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '$spare hours left',
                style: text.titleMedium?.copyWith(
                  color: spare > 0 ? Tokens.textOnDark : Tokens.mutedOnDark,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text(
                'START OVER',
                style: TextStyle(color: Tokens.mutedOnDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space2),
        // Two rows of three, stretched to the room left: the whole day is
        // visible at once and never needs a scroll.
        Expanded(
          child: Column(
            children: <Widget>[
              for (var row = 0; row < Activity.values.length; row += 3) ...[
                if (row > 0) const SizedBox(height: Tokens.space2),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      for (final activity in Activity.values.skip(row).take(3))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Tokens.space1,
                            ),
                            child: _Tile(
                              activity: activity,
                              hours: plan[activity] ?? 0,
                              onAdd: spare > 0 ? () => onAdd(activity) : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// What each way of spending an hour is called, and what it is for.
String labelOf(Activity activity) => switch (activity) {
  Activity.work => 'work a shift',
  Activity.sleep => 'sleep',
  Activity.eat => 'eat something',
  Activity.study => 'read up on the football',
  Activity.watch => 'watch a match',
  Activity.idle => 'do nothing much',
};

IconData _iconOf(Activity activity) => switch (activity) {
  Activity.work => Icons.work,
  Activity.sleep => Icons.bedtime,
  Activity.eat => Icons.restaurant,
  Activity.study => Icons.menu_book,
  Activity.watch => Icons.live_tv,
  Activity.idle => Icons.weekend,
};

class _Tile extends StatelessWidget {
  const new({required this.activity, required this.hours, this.onAdd});

  final Activity activity;
  final int hours;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final live = onAdd != null;
    return Tooltip(
      message: 'an hour of ${labelOf(activity)}',
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(Tokens.radius),
        child: Container(
          padding: const EdgeInsets.all(Tokens.space2),
          decoration: BoxDecoration(
            color: Tokens.inkRaised1,
            borderRadius: BorderRadius.circular(Tokens.radius),
            border: Border.all(color: live ? Tokens.accent : Tokens.lineDark),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 96,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _iconOf(activity),
                    color: live ? Tokens.accent : Tokens.lineDark,
                  ),
                  Text(
                    labelOf(activity),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                  Text(
                    hours == 0 ? '--' : '${hours}h',
                    style: text.bodyMedium?.copyWith(
                      color: hours == 0 ? Tokens.mutedOnDark : Tokens.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
