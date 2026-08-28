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
