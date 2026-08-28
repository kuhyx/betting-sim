import 'package:betting_sim/ui/matchday_screen.dart';
import 'package:betting_sim/ui/tokens.dart';
import 'package:flutter/foundation.dart';
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
      // The ONE read of kDebugMode in the app. The balance knobs let a
      // player rewrite the game's difficulty, so the surface must not ship;
      // scripts/check_debug_absent.sh asserts that on the built artifact.
      home: const MatchdayScreen(showDebugTuning: kDebugMode),
    );
  }
}
