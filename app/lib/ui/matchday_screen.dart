import 'dart:async';

import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:betting_sim/ui/action_bar.dart';
import 'package:betting_sim/ui/debug_panel.dart';
import 'package:betting_sim/ui/fixture_tile.dart';
import 'package:betting_sim/ui/results_sheet.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// The playable slice: fixtures, prices, a bet slip and a settle button.
///
/// A view, not an owner: `HomeShell` holds the [GameState] so that the feed,
/// friends and life tabs read the same bankroll and the same calendar.
class MatchdayScreen extends StatefulWidget {
  /// Creates the screen over [game].
  ///
  /// [showDebugTuning] is a required plain bool rather than a `kDebugMode`
  /// default: the constant is read in exactly one place, `main.dart`, so the
  /// panel cannot be reached in a release build, and tests can drive both
  /// states without one. Defaulting it here would also const-fold to `true`
  /// under `flutter test` and trip avoid_redundant_argument_values.
  const MatchdayScreen({
    required this.game,
    required this.showDebugTuning,
    required this.onRetune,
    required this.onSettled,
    super.key,
  });

  /// The game being played.
  final GameState game;

  /// Whether the debug tuning surface may be shown.
  final bool showDebugTuning;

  /// Called when a balance knob moves, which restarts the season.
  final ValueChanged<Tuning> onRetune;

  /// Called once a matchday has settled, so the shell can save.
  final Future<void> Function() onSettled;

  @override
  State<MatchdayScreen> createState() => _MatchdayScreenState();
}

class _MatchdayScreenState extends State<MatchdayScreen> {
  OddsFormat _format = OddsFormat.decimal;
  double _stakeSize = 10;

  GameState get _game => widget.game;

  void _cycleFormat() {
    setState(() {
      _format =
          OddsFormat.values[(_format.index + 1) % OddsFormat.values.length];
    });
  }

  void _settle() {
    final before = _game.history.length;
    _game.advanceDay();
    final settled = _game.history.take(_game.history.length - before).toList();
    unawaited(widget.onSettled());
    if (settled.isNotEmpty && mounted) {
      // Nothing here waits on the sheet closing -- the day is already
      // settled by the time it opens, so it is a report, not a step.
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Tokens.inkRaised1,
          builder: (_) => ResultsSheet(bets: settled),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text(
          _game.seasonOver
              ? 'season over'
              : 'matchday ${_game.day + 1} of ${_game.totalDays}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _cycleFormat,
            child: Text(
              _format.name,
              style: const TextStyle(color: Tokens.accent),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _BankrollBar(bankroll: _game.bankroll, staked: _game.slipStake),
          Expanded(
            child: _game.seasonOver
                ? const _SeasonOver()
                : ListView.separated(
                    padding: const EdgeInsets.all(Tokens.space4),
                    itemCount: _game.fixtures.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Tokens.space3),
                    itemBuilder: (_, i) {
                      final card = _game.fixtures[i];
                      return FixtureTile(
                        card: card,
                        format: _format,
                        staked: _game.slip[card.index],
                        onStake: (selection) => _game.stake(
                          card.index,
                          selection,
                          _game.slip[card.index]?.selection == selection
                              ? 0
                              : _stakeSize,
                        ),
                      );
                    },
                  ),
          ),
          DebugTuningPanel(
            tuning: _game.tuning,
            performance: _game.performance,
            onChanged: widget.onRetune,
            enabled: widget.showDebugTuning,
          ),
          if (!_game.seasonOver)
            ActionBar(
              stakeSize: _stakeSize,
              onStakeChanged: (v) => setState(() => _stakeSize = v),
              onSettle: _settle,
              hasBets: _game.slip.isNotEmpty,
            ),
        ],
      ),
    );
  }
}

class _BankrollBar extends StatelessWidget {
  const _BankrollBar({required this.bankroll, required this.staked});

  final double bankroll;
  final double staked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Tokens.inkRaised1,
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'bankroll ${bankroll.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Tokens.textOnDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (staked > 0)
            Text(
              'staked ${staked.toStringAsFixed(0)}',
              style: const TextStyle(color: Tokens.accent, fontSize: 14),
            ),
        ],
      ),
    );
  }
}

class _SeasonOver extends StatelessWidget {
  const _SeasonOver();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'season complete',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
