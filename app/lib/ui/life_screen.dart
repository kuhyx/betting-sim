import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/life.dart';
import 'package:betting_sim/ui/day_planner.dart';
import 'package:betting_sim/ui/needs_bars.dart';
import 'package:betting_sim/ui/shop.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// The week around the football.
///
/// Where the stakes are. The bankroll used to be a score; here it is what the
/// rent comes out of, and the hours you spend reading up on a fixture are
/// hours you were not paid for.
class LifeScreen extends StatefulWidget {
  /// Creates the screen over [game].
  const LifeScreen({required this.game, super.key});

  /// The game being played.
  final GameState game;

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  final Map<Activity, int> _plan = <Activity, int>{};
  bool _shopping = false;

  void _add(Activity activity) =>
      setState(() => _plan[activity] = (_plan[activity] ?? 0) + 1);

  void _clear() => setState(_plan.clear);

  void _live() {
    final hours = <Activity>[
      for (final entry in _plan.entries)
        for (var i = 0; i < entry.value; i++) entry.key,
    ];
    setState(() {
      widget.game.liveDay(hours);
      _plan.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final life = widget.game.life;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text(life.date.label, style: text.headlineSmall),
        actions: <Widget>[
          TextButton(
            onPressed: () => setState(() => _shopping = !_shopping),
            child: Text(
              _shopping ? 'today' : 'shop',
              style: const TextStyle(color: Tokens.accent),
            ),
          ),
        ],
      ),
      body: _shopping
          ? Shop(game: widget.game)
          : !life.running
          ? _Over(life: life)
          : ListView(
              padding: const EdgeInsets.all(Tokens.space4),
              children: <Widget>[
                _Money(game: widget.game),
                const SizedBox(height: Tokens.space4),
                NeedsBars(needs: life.needs),
                const SizedBox(height: Tokens.space4),
                HourPlanner(
                  life: life,
                  plan: _plan,
                  onAdd: _add,
                  onClear: _clear,
                ),
              ],
            ),
      bottomNavigationBar: !life.running || _shopping
          ? null
          : Padding(
              padding: const EdgeInsets.all(Tokens.space3),
              child: FilledButton(
                onPressed: _live,
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  foregroundColor: Tokens.onFill,
                ),
                child: Text(
                  life.date.weekday == Weekday.saturday
                      ? 'GET THROUGH SATURDAY'
                      : 'GET THROUGH THE DAY',
                ),
              ),
            ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final life = game.life;
    final behind = life.arrears > 0;
    return Container(
      width: double.infinity,
      color: Tokens.inkRaised1,
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            game.bankroll.toStringAsFixed(2),
            style: text.headlineSmall,
          ),
          const SizedBox(height: Tokens.space1),
          Text(
            behind
                ? 'you are ${life.arrears} week'
                      '${life.arrears == 1 ? '' : 's'} behind on the rent'
                : 'rent is ${life.config.rentPerWeek.toStringAsFixed(0)}, '
                      'every ${LifeState.rentDay.label}',
            style: text.bodySmall?.copyWith(
              color: behind ? Tokens.danger : Tokens.mutedOnDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Over extends StatelessWidget {
  const _Over({required this.life});

  final LifeState life;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final evicted = life.ending == RunEnding.evicted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              evicted ? 'put out' : 'season over',
              style: text.headlineSmall?.copyWith(
                color: evicted ? Tokens.danger : Tokens.accent,
              ),
            ),
            const SizedBox(height: Tokens.space3),
            Text(
              evicted
                  ? 'the rent went unpaid once too often. that is the run.'
                  : 'you made it to the end of the season still housed.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: Tokens.mutedOnDark),
            ),
          ],
        ),
      ),
    );
  }
}
