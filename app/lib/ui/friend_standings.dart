import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:league_engine/league_engine.dart';

/// Where each friendship stands, in money.
class FriendStandings extends StatelessWidget {
  /// Creates the table.
  const FriendStandings({
    required this.book,
    required this.friends,
    super.key,
  });

  /// The running totals.
  final FriendBook book;

  /// Who they are.
  final List<Friend> friends;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = book.standings;
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: Text(
            'shake on something and it starts adding up here.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: Tokens.mutedOnDark),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Tokens.space4),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        final friend = friends[row.friendId];
        final ahead = row.balance >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: Tokens.space2),
          padding: const EdgeInsets.all(Tokens.space3),
          color: Tokens.inkRaised1,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(friend.name, style: text.bodyMedium),
                    Text(
                      '${row.bets} bet${row.bets == 1 ? '' : 's'}',
                      style: text.bodySmall?.copyWith(
                        color: Tokens.mutedOnDark,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${ahead ? '+' : ''}${row.balance.toStringAsFixed(2)}',
                style: text.bodyMedium?.copyWith(
                  color: ahead ? Tokens.success : Tokens.danger,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
