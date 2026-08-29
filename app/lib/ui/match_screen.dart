import 'dart:async';

import 'package:betting_sim/state/settler.dart';
import 'package:betting_sim/ui/match_events.dart';
import 'package:betting_sim/ui/match_stats_panel.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// Watching a match that has already been decided.
///
/// The result was settled the moment the matchday was played; this screen
/// replays the timeline the narrator generated from the same seed. Nothing
/// here can change the score, which is exactly why it is safe to let the
/// player scrub, skip, and watch it twice.
class MatchScreen extends StatefulWidget {
  /// Creates the screen for [match].
  const MatchScreen({required this.match, super.key});

  /// The match being watched.
  final PlayedMatch match;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  static const _narrator = MatchNarrator();
  static const _fullTime = 90;

  late final MatchTimeline _timeline = _narrator.narrate(
    widget.match.context,
    widget.match.result,
  );

  int _minute = 0;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  bool get _running => _clock != null;

  void _start() {
    _clock = Timer.periodic(const Duration(milliseconds: 90), (_) {
      setState(() {
        _minute++;
        if (_minute >= _fullTime) {
          _minute = _fullTime;
          _stop();
        }
      });
    });
  }

  void _stop() {
    _clock?.cancel();
    _clock = null;
  }

  void _toggle() {
    setState(() {
      if (_running) {
        _stop();
      } else {
        if (_minute >= _fullTime) {
          _minute = 0;
        }
        _start();
      }
    });
  }

  void _skip() {
    setState(() {
      _stop();
      _minute = _fullTime;
    });
  }

  /// The score as it stood at [_minute] -- counted from the events on screen,
  /// never from the final result, so the number always matches what has been
  /// shown.
  (int, int) get _score {
    var home = 0;
    var away = 0;
    for (final goal in _shown.whereType<GoalEvent>()) {
      goal.byHome ? home++ : away++;
    }
    return (home, away);
  }

  List<MatchEvent> get _shown => _timeline.upTo(_minute);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (home, away) = _score;
    final done = _minute >= _fullTime;
    final shown = _shown.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text(
          '${widget.match.home.name} v ${widget.match.away.name}',
          style: text.titleMedium,
        ),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: Tokens.inkRaised1,
            padding: const EdgeInsets.all(Tokens.space4),
            child: Column(
              children: <Widget>[
                Text('$home - $away', style: text.headlineSmall),
                const SizedBox(height: Tokens.space2),
                Text(
                  done ? 'full time' : "$_minute'",
                  style: text.bodySmall?.copyWith(color: Tokens.accent),
                ),
                const SizedBox(height: Tokens.space2),
                LinearProgressIndicator(
                  value: _minute / _fullTime,
                  backgroundColor: Tokens.lineDark,
                  color: Tokens.accent,
                ),
                const SizedBox(height: Tokens.space2),
                Text(
                  '${widget.match.context.weather.name} · '
                  '${_timeline.homeSheet.missing.length} out for '
                  '${widget.match.home.name}',
                  style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      'nothing yet',
                      style: text.bodySmall?.copyWith(
                        color: Tokens.mutedOnDark,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) => MatchEventRow(
                      event: shown[i],
                      match: widget.match,
                    ),
                  ),
          ),
          MatchStatsPanel(
            home: _timeline.home,
            away: _timeline.away,
            revealed: done,
          ),
          Padding(
            padding: const EdgeInsets.all(Tokens.space3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                TextButton(
                  onPressed: _toggle,
                  child: Text(
                    _running ? 'PAUSE' : (done ? 'WATCH AGAIN' : 'RESUME'),
                    style: const TextStyle(color: Tokens.accent),
                  ),
                ),
                TextButton(
                  onPressed: done ? null : _skip,
                  child: const Text(
                    'FULL TIME',
                    style: TextStyle(color: Tokens.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
