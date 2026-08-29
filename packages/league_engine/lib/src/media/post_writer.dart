import 'package:league_engine/src/book/pricing.dart';
import 'package:league_engine/src/latent/state.dart';
import 'package:league_engine/src/league/entities.dart';
import 'package:league_engine/src/media/tipster.dart';
import 'package:league_engine/src/rng/source.dart';

/// Writes the words a tipster puts under their call.
///
/// Templated on purpose. The post has to carry TONE without carrying
/// information: if the writing told you how good the opinion was, keeping
/// records would be pointless and the whole feed would be a hint system.
/// So the loudest phrasing is reserved for the highest [Tipster.confidence],
/// which is drawn independently of how much the tipster actually knows.
String writePost({
  required Tipster tipster,
  required Selection selection,
  required Team home,
  required Team away,
  required Weather weather,
  required RandomSource rng,
}) {
  final side = switch (selection) {
    Selection.home => home.name,
    Selection.away => away.name,
    Selection.draw => 'the draw',
  };
  final other = switch (selection) {
    Selection.home => away.name,
    Selection.away => home.name,
    Selection.draw => '${home.name} v ${away.name}',
  };

  final opener = _pick(_openers(tipster.confidence), rng);
  final angle = _pick(_angles(tipster.angle), rng);
  final closer = _pick(_closers(weather), rng);
  return '$opener $side. $angle $closer'
      .replaceAll('{other}', other)
      .replaceAll('{side}', side);
}

List<String> _openers(double confidence) {
  if (confidence > 0.8) {
    return const <String>[
      'this is the lock of the round —',
      'i am maximum on',
      'biggest bet of my week:',
      'if you take one thing off me, take',
    ];
  }
  if (confidence > 0.5) {
    return const <String>[
      'quite like',
      'leaning toward',
      'the play here is',
      'happy enough on',
    ];
  }
  return const <String>[
    'small one on',
    'not confident, but',
    'a nibble on',
    'if pushed:',
  ];
}

List<String> _angles(TipsterAngle angle) => switch (angle) {
  TipsterAngle.straight => const <String>[
    'numbers say the price is wrong.',
    'nothing clever, just value.',
    'been on this line all week.',
  ],
  TipsterAngle.homer => const <String>[
    'you do not travel there and take anything.',
    'home crowd is worth a goal on its own.',
    'never back against a side at home in this league.',
  ],
  TipsterAngle.favourite => const <String>[
    'good teams beat bad teams. that is the whole system.',
    'stop overthinking it, take the better side.',
    'class tells in the end.',
  ],
  TipsterAngle.contrarian => const <String>[
    'everyone is on {other} and everyone is wrong.',
    'fading the public here, as usual.',
    'the crowd has made {other} far too short.',
  ],
};

List<String> _closers(Weather weather) => switch (weather) {
  Weather.clear => const <String>['', 'no excuses in these conditions.'],
  Weather.rain => const <String>[
    'wet pitch helps too.',
    'rain forecast, which suits {side}.',
  ],
  Weather.storm => const <String>[
    'wind will make it ugly, mind.',
    'weather is a genuine worry.',
  ],
};

String _pick(List<String> options, RandomSource rng) =>
    options[rng.randint(0, options.length - 1)];
