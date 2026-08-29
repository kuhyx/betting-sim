import 'package:betting_sim/state/settler.dart';
import 'package:betting_sim/ui/match_screen.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// The matches from the round just played, each one openable.
class LastMatchdayScreen extends StatelessWidget {
  /// Creates the list for [matches].
  const LastMatchdayScreen({required this.matches, super.key});

  /// What was played.
  final List<PlayedMatch> matches;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text('last matchday', style: text.headlineSmall),
      ),
      body: matches.isEmpty
          ? Center(
              child: Text(
                'nothing played yet',
                style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(Tokens.space4),
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
              itemBuilder: (_, i) => _MatchRow(match: matches[i]),
            ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final PlayedMatch match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MatchScreen(match: match)),
      ),
      child: Container(
        color: Tokens.inkRaised1,
        padding: const EdgeInsets.all(Tokens.space4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${match.home.name} v ${match.away.name}',
                style: text.bodyMedium,
              ),
            ),
            Text(match.scoreline, style: text.titleMedium),
            const SizedBox(width: Tokens.space3),
            const Icon(Icons.play_circle_outline, color: Tokens.accent),
          ],
        ),
      ),
    );
  }
}
