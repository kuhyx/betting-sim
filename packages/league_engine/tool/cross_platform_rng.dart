/// Prints a fingerprint of the engine's RNG: seed derivation plus draws.
///
/// Compiled to JavaScript and run on the VM, this must emit byte-identical
/// output. `scripts/check_rng_parity.sh` asserts exactly that. A save is a
/// seed plus event deltas, so if the two platforms disagree by even one bit,
/// a game synced from the phone replays differently on the desktop.
library;

import 'package:league_engine/league_engine.dart';

void main() {
  final lines = <String>[];

  // Transcendental math, NOT just the RNG. ECMAScript does not require exact
  // results for exp/log/pow, while the VM uses libm -- so a season simulated
  // on the phone could silently diverge from the same seed in the Chrome
  // build. That would break the seed+deltas save format across exactly the two
  // platforms this ships to.
  final league = generateLeague(20260828);
  const runner = MatchRunner(model: DixonColesModel());
  for (final day in <int>[0, 7, 21]) {
    final fixture = league.fixturesOn(day).first;
    final ctx = runner.contextFor(
      home: league.teamById(fixture.homeId),
      away: league.teamById(fixture.awayId),
      homeState: const LatentState(fatigue: 0.4, morale: -0.3),
      awayState: const LatentState(form: 0.5),
      seedPath: SeedPath(master: 20260828, season: 0, day: day, match: 0),
    );
    final probs = ctx.weather.name;
    final result = runner.run(ctx);
    final minutes = result.events.map((e) => e.minute).join(',');
    final p = const DixonColesModel().outcomeProbabilities(ctx);
    lines.add(
      'match$day|$probs|${result.homeScore}-${result.awayScore}'
      '|$minutes|${p.home.toStringAsFixed(12)}'
      '|${p.draw.toStringAsFixed(12)}',
    );
  }

  // Glicko-2 exercises exp, log, sqrt and the volatility solver's iteration.
  final rated = const Glicko2Updater().update(
    const Rating(deviation: 200),
    <RatingResult>[
      const RatingResult(
        opponent: Rating(rating: 1400, deviation: 30),
        score: 1,
      ),
      const RatingResult(
        opponent: Rating(rating: 1550, deviation: 100),
        score: 0,
      ),
    ],
  );
  lines.add(
    'glicko|${rated.rating.toStringAsFixed(12)}'
    '|${rated.deviation.toStringAsFixed(12)}'
    '|${rated.volatility.toStringAsFixed(12)}',
  );
  for (final path in <SeedPath>[
    const SeedPath(master: 0),
    const SeedPath(master: 20260828),
    const SeedPath(master: 20260828, season: 1, day: 7, match: 3),
  ]) {
    final rng = Mix32Source(deriveSeed(path));
    final draws = <String>[
      for (var i = 0; i < 4; i++) rng.uniform01().toStringAsFixed(12),
    ];
    final ints = <int>[for (var i = 0; i < 3; i++) rng.randint(0, 999)];
    final pois = <int>[for (var i = 0; i < 3; i++) rng.poisson(1.4)];
    lines.add(
      '${seedHex(path)}|${draws.join(",")}|${ints.join(",")}|${pois.join(",")}',
    );
  }
  // This is a diagnostic probe whose entire purpose is to emit a fingerprint
  // on stdout for the parity script to diff; there is no logger to route to.
  // ignore: avoid_print
  print(lines.join('\n'));
}
