import 'package:betting_sim/ui/matchday_screen.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BettingSimApp());
}

/// The app shell.
class BettingSimApp extends StatelessWidget {
  /// Creates the app.
  const BettingSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'betting-sim',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: const MatchdayScreen(),
    );
  }
}
