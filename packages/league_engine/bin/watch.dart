import 'dart:io';

import 'package:league_engine/league_engine.dart';

/// Prints a narrated match report, headless.
///
///     dart run bin/watch.dart [masterSeed] [day] [match]
///
/// Writes through `stdout` rather than `print` so the file needs no
/// `avoid_print` suppression.
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 20260828;
  final day = args.length > 1 ? int.parse(args[1]) : 0;
  final index = args.length > 2 ? int.parse(args[2]) : 0;

  final league = generateLeague(seed);
  final fixture = league.fixturesOn(day)[index];
  final home = league.teamById(fixture.homeId);
  final away = league.teamById(fixture.awayId);

  const runner = MatchRunner(model: DixonColesModel());
  final ctx = runner.contextFor(
    home: home,
    away: away,
    // A tired, out-of-form, injury-hit home side against a fragile one, so
    // the fingerprints are visible in a single match rather than only across
    // a season.
    homeState: const LatentState(fatigue: 0.9, form: -0.8, injuredCount: 2),
    awayState: const LatentState(morale: -0.9),
    seedPath: SeedPath(master: seed, season: 0, day: day, match: index),
  );
  final result = runner.run(ctx);
  final timeline = runner.narrate(ctx, result);

  final out = StringBuffer()
    ..writeln(
      '${home.name} ${result.homeScore}-'
      '${result.awayScore} ${away.name}',
    )
    ..writeln(
      '${ctx.weather.name}, '
      'referee ${ctx.refereeBias.toStringAsFixed(3)}',
    )
    ..writeln();
  for (final e in timeline.events) {
    out.writeln("  ${e.minute.toString().padLeft(3)}'  $e");
  }
  out.writeln();

  final h = timeline.home;
  final a = timeline.away;
  _row(out, '', 'home', 'away');
  _row(out, 'shots', '${h.shots}', '${a.shots}');
  _row(out, '  2nd half', '${h.secondHalfShots}', '${a.secondHalfShots}');
  _row(out, 'on target', '${h.shotsOnTarget}', '${a.shotsOnTarget}');
  _row(out, 'corners', '${h.corners}', '${a.corners}');
  _row(out, 'fouls', '${h.fouls}', '${a.fouls}');
  _row(out, 'yellows', '${h.yellows}', '${a.yellows}');
  _row(out, 'reds', '${h.reds}', '${a.reds}');
  _row(
    out,
    'possession',
    h.possessionPercent.toStringAsFixed(1),
    a.possessionPercent.toStringAsFixed(1),
  );

  out
    ..writeln()
    ..writeln(
      'missing: '
      '${timeline.homeSheet.missing.map((p) => p.name).join(", ")}',
    )
    ..writeln(
      'xi:      '
      '${timeline.homeSheet.starting.map((p) => p.name).join(", ")}',
    );
  stdout.write(out);
}

void _row(StringBuffer out, String label, String home, String away) =>
    out.writeln('${label.padRight(12)}${home.padLeft(6)}${away.padLeft(6)}');
