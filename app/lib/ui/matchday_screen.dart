import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/ui/action_bar.dart';
import 'package:betting_sim/ui/fixture_tile.dart';
import 'package:betting_sim/ui/results_sheet.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// The playable slice: fixtures, prices, a bet slip and a settle button.
class MatchdayScreen extends StatefulWidget {
  /// Creates the screen.
  const MatchdayScreen({super.key});

  @override
  State<MatchdayScreen> createState() => _MatchdayScreenState();
}

class _MatchdayScreenState extends State<MatchdayScreen> {
  final GameState _game = GameState();
  OddsFormat _format = OddsFormat.decimal;
  double _stakeSize = 10;

  @override
  void initState() {
    super.initState();
    _game.addListener(_onChanged);
  }

  @override
  void dispose() {
    _game
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

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
    if (settled.isNotEmpty && mounted) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Tokens.inkRaised1,
        builder: (_) => ResultsSheet(bets: settled),
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
