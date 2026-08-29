import 'dart:io';

import 'package:league_engine/league_engine.dart';

/// Prints what the internet is saying about one fixture.
///
///     dart run bin/feed.dart [masterSeed] [day] [match]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 20260828;
  final day = args.length > 1 ? int.parse(args[1]) : 4;
  final index = args.length > 2 ? int.parse(args[2]) : 0;

  final league = generateLeague(seed);
  final fixture = league.fixturesOn(day)[index];
  final home = league.teamById(fixture.homeId);
  final away = league.teamById(fixture.awayId);

  const runner = MatchRunner(model: DixonColesModel());
  final path = SeedPath(master: seed, season: 0, day: day, match: index);
  final ctx = runner.contextFor(
    home: home,
    away: away,
    homeState: const LatentState(fatigue: 0.7, form: 0.5),
    awayState: const LatentState(morale: -0.6, injuredCount: 3),
    seedPath: path,
  );
  const maker = MarketMaker(
    model: DixonColesModel(),
    bookmaker: Bookmaker(),
    openingLine: OpeningLine(),
    flow: MoneyFlow(),
    bookLatentAwareness: 0.7,
  );
  final market = maker
      .marketsFor(ctx: ctx, home: home, away: away, path: path)
      .opening;

  final tipsters = generateTipsters(seed);
  final tips = const TipsterDesk().tipsFor(
    ctx: ctx,
    path: path,
    tipsters: tipsters,
    market: market,
  );

  final out = StringBuffer()
    ..writeln('${home.name} v ${away.name}   (${ctx.weather.name})')
    ..writeln(
      'price  H ${market.priceOf(Selection.home).decimal.toStringAsFixed(2)}'
      '  D ${market.priceOf(Selection.draw).decimal.toStringAsFixed(2)}'
      '  A ${market.priceOf(Selection.away).decimal.toStringAsFixed(2)}',
    )
    ..writeln();
  for (final tip in tips) {
    final t = tipsters[tip.tipsterId];
    out
      ..writeln('${tip.handle}  [${tip.selection.name}]')
      ..writeln('    "${tip.text}"')
      ..writeln(
        '    (hidden: awareness ${t.awareness.toStringAsFixed(2)}, '
        'angle ${t.angle.name}, '
        'edge ${(tip.edgeAgainst(market) * 100).toStringAsFixed(1)}pp)',
      );
  }
  stdout.write(out);
}
