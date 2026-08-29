import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

/// A tab that exists but is not built yet.
///
/// Shipped deliberately rather than hidden: the shell's four destinations are
/// the shape of the finished game, and naming what is coming is more honest
/// than a navigation bar that grows a button at a time.
class PlaceholderTab extends StatelessWidget {
  /// Creates a placeholder titled [title], explained by [blurb].
  const PlaceholderTab({required this.title, required this.blurb, super.key});

  /// The tab's name.
  final String title;

  /// One line on what will live here.
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.inkRaised1,
        title: Text(title, style: text.headlineSmall),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'not built yet',
                style: text.titleMedium?.copyWith(color: Tokens.accent),
              ),
              const SizedBox(height: Tokens.space3),
              Text(
                blurb,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: Tokens.mutedOnDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
