import 'dart:async';

import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:betting_sim/state/save.dart';
import 'package:betting_sim/state/save_store.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:betting_sim/ui/feed_screen.dart';
import 'package:betting_sim/ui/friends_screen.dart';
import 'package:betting_sim/ui/life_screen.dart';
import 'package:betting_sim/ui/matchday_screen.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// The root of the app: one game, four places to spend it.
///
/// Owns the [GameState] and the save, so every tab reads one bankroll and one
/// calendar. The tabs below it are views; none of them constructs a game.
class HomeShell extends StatefulWidget {
  /// Creates the shell.
  ///
  /// [store] is injectable so widget tests can run without a platform
  /// channel; it defaults to real on-device storage.
  const HomeShell({required this.showDebugTuning, this.store, super.key});

  /// Whether the debug tuning surface may be shown.
  final bool showDebugTuning;

  /// Where the save is read from and written to.
  final SaveStore? store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final SaveStore _store = widget.store ?? PrefsSaveStore();
  GameState? _game;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _game
      ?..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final save = SaveData.decode(await _store.read());
    if (!mounted) {
      return;
    }
    // A save that would not parse is not an error to report: decode already
    // decided it is unusable, and the only sane response is a new game.
    _adopt(save == null ? GameState() : GameState.fromSave(save));
  }

  void _adopt(GameState game) {
    final old = _game;
    setState(() => _game = game..addListener(_onChanged));
    old
      ?..removeListener(_onChanged)
      ..dispose();
  }

  void _onChanged() => setState(() {});

  /// Writes the game to storage. Called after anything that moves the season
  /// on -- never on a bet slip change, which is not yet a commitment.
  Future<void> _persist() async {
    final game = _game;
    if (game != null) {
      await _store.write(game.toSave().encode());
    }
  }

  /// Rebuilds the season under [tuning].
  ///
  /// A full restart, not a re-price: the knobs decide what the book quotes, so
  /// every fixture already shown was priced under the old value and the
  /// bankroll it produced is no longer comparable. The master seed is
  /// deliberately CARRIED OVER -- the same fixtures at a different awareness
  /// is what makes the setting feelable rather than merely different.
  void _retune(Tuning tuning) {
    _adopt(GameState(masterSeed: _game!.masterSeed, tuning: tuning));
    unawaited(_persist());
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          MatchdayScreen(
            game: game,
            showDebugTuning: widget.showDebugTuning,
            onRetune: _retune,
            onSettled: _persist,
          ),
          FeedScreen(game: game),
          FriendsScreen(game: game),
          LifeScreen(game: game),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Tokens.inkRaised1,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.sports_soccer),
            label: 'matches',
          ),
          NavigationDestination(icon: Icon(Icons.forum), label: 'feed'),
          NavigationDestination(icon: Icon(Icons.people), label: 'friends'),
          NavigationDestination(icon: Icon(Icons.home), label: 'life'),
        ],
      ),
    );
  }
}
