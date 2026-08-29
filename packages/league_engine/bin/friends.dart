import 'dart:io';

import 'package:league_engine/league_engine.dart';

/// Prints what your friends want on one fixture, and what a shrewd head
/// would do about each of them.
///
///     dart run bin/friends.dart [masterSeed] [day] [match]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 20260828;
  final day = args.length > 1 ? int.parse(args[1]) : 6;
  final index = args.length > 2 ? int.parse(args[2]) : 0;

  final league = generateLeague(seed);
  final fixture = league.fixturesOn(day)[index];
  final home = league.teamById(fixture.homeId);
  final away = league.teamById(fixture.awayId);
  final path = SeedPath(master: seed, season: 0, day: day, match: index);

  const runner = MatchRunner(model: DixonColesModel());
  final ctx = runner.contextFor(
    home: home,
    away: away,
    homeState: const LatentState(fatigue: 0.6, form: 0.4),
    awayState: const LatentState(morale: -0.5, injuredCount: 2),
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
  final view = BettingView(
    market: market,
    context: ctx,
    observedHomeFatigue: 0.6,
    observedAwayFatigue: 0,
    observedHomeForm: 0.4,
    observedAwayForm: 0,
  );

  final friends = generateFriends(
    seed,
    <int>[for (final t in league.teams) t.id],
  );
  final terms = const FriendCircle().proposalsFor(
    ctx: ctx,
    path: path,
    friends: friends,
    market: market,
  );

  const shrewd = ShrewdReviewer();
  final out = StringBuffer()
    ..writeln('${home.name} v ${away.name}')
    ..writeln(
      'book   H ${market.priceOf(Selection.home).decimal.toStringAsFixed(2)}'
      '  D ${market.priceOf(Selection.draw).decimal.toStringAsFixed(2)}'
      '  A ${market.priceOf(Selection.away).decimal.toStringAsFixed(2)}',
    )
    ..writeln();
  if (terms.isEmpty) {
    out.writeln('nobody fancies it.');
  }
  for (final term in terms) {
    final p = term.proposal;
    final decision = shrewd.review(p, view);
    final counter = decision.counter;
    final String verdict;
    if (decision.accepted) {
      verdict = 'ACCEPT';
    } else if (counter == null) {
      verdict = 'reject';
    } else {
      final shake = term.wouldAccept(counter) ? 'they take it' : 'they walk';
      verdict = 'counter at ${counter.decimal.toStringAsFixed(2)} ($shake)';
    }
    out
      ..writeln('${p.name} (${friends[p.friendId].bias.name})')
      ..writeln('    "${p.message}"')
      ..writeln(
        '    wants ${p.selection.name} @ '
        '${p.odds.decimal.toStringAsFixed(2)} for ${p.stake.toStringAsFixed(0)}'
        ' -- you risk ${p.atRisk.toStringAsFixed(0)}',
      )
      ..writeln('    -> $verdict');
  }
  stdout.write(out);
}
