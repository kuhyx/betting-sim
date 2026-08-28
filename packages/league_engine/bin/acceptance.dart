import 'package:league_engine/league_engine.dart';

/// Runs the acceptance gate and prints its report.
///
/// Usage: dart run bin/acceptance.dart [seasons] [masterSeed]
void main(List<String> args) {
  final seasons = args.isNotEmpty ? int.parse(args[0]) : 200;
  final masterSeed = args.length > 1 ? int.parse(args[1]) : 9000;

  final started = DateTime.now();
  final report = runAcceptance(seasons: seasons, masterSeed: masterSeed);
  final elapsed = DateTime.now().difference(started);

  // This is a report generator; stdout is its entire purpose.
  // ignore: avoid_print
  print(formatReport(report, elapsed));
}
