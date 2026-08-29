import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/rng/source.dart';
import 'package:league_engine/src/social/friend.dart';

/// Writes the message a friend sends with a proposal.
///
/// Tone follows the BIAS, not the quality of the bet. A friend who has been
/// wrong forty weeks running is exactly as breezy about it as one who has
/// not, which is why the ledger in the app is worth keeping.
String writeProposal({
  required Friend friend,
  required Selection selection,
  required Team home,
  required Team away,
  required double stake,
  required RandomSource rng,
}) {
  final side = switch (selection) {
    Selection.home => home.name,
    Selection.away => away.name,
    Selection.draw => 'the draw',
  };
  final opener = _pick(switch (friend.bias) {
    FriendBias.chalk => const <String>[
      'easiest money of the weekend.',
      'no way they slip up here.',
      'this is basically free.',
    ],
    FriendBias.longshot => const <String>[
      'i know, i know. hear me out.',
      'the price is too big to ignore.',
      'one of these lands eventually.',
    ],
    FriendBias.loyal => const <String>[
      'you know i cannot bet against them.',
      'we are due. i can feel it.',
      'i have watched every game. trust me.',
    ],
    FriendBias.cagey => const <String>[
      'nobody wants to lose this one.',
      'two sides who cannot score. do the maths.',
      'it will be a scrappy 1-1, watch.',
    ],
  }, rng);

  return '$opener ${stake.toStringAsFixed(0)} on $side?';
}

String _pick(List<String> options, RandomSource rng) =>
    options[rng.randint(0, options.length - 1)];
