import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

Team _club(int id, String name) => Team(
  id: id,
  name: name,
  town: 'Town$id',
  players: const <Player>[],
  rating: const Rating(),
);

Tipster _tipster(TipsterAngle angle, double confidence) => Tipster(
  id: 0,
  handle: '@t',
  awareness: 0,
  noise: 0,
  angle: angle,
  confidence: confidence,
);

void main() {
  final home = _club(1, 'Ashcombe');
  final away = _club(2, 'Draymoor');

  String post({
    TipsterAngle angle = TipsterAngle.straight,
    double confidence = 0.6,
    Selection selection = Selection.home,
    Weather weather = Weather.clear,
    int seed = 5,
  }) => writePost(
    tipster: _tipster(angle, confidence),
    selection: selection,
    home: home,
    away: away,
    weather: weather,
    rng: Mix32Source(seed),
  );

  group('writePost', () {
    test('names the side being tipped', () {
      expect(post(), contains('Ashcombe'));
      expect(post(selection: Selection.away), contains('Draymoor'));
      expect(post(selection: Selection.draw), contains('the draw'));
    });

    test('gets louder with confidence, and says nothing about being right', () {
      // The loud phrasing is reserved for high confidence, which is drawn
      // independently of awareness -- so tone is a tell about temperament,
      // never about edge.
      final loud = <String>[
        for (var s = 0; s < 40; s++) post(confidence: 0.95, seed: s),
      ];
      final quiet = <String>[
        for (var s = 0; s < 40; s++) post(confidence: 0.2, seed: s),
      ];
      expect(loud.any((p) => p.contains('lock of the round')), isTrue);
      expect(quiet.any((p) => p.contains('not confident')), isTrue);
      expect(loud.any((p) => p.contains('not confident')), isFalse);

      final middling = <String>[
        for (var s = 0; s < 40; s++) post(confidence: 0.65, seed: s),
      ];
      expect(middling.any((p) => p.contains('quite like')), isTrue);
    });

    test('writes to the angle', () {
      List<String> many(TipsterAngle angle) => <String>[
        for (var s = 0; s < 40; s++) post(angle: angle, seed: s),
      ];
      expect(
        many(TipsterAngle.homer).any((p) => p.contains('home crowd')),
        isTrue,
      );
      expect(
        many(TipsterAngle.favourite).any((p) => p.contains('class tells')),
        isTrue,
      );
      expect(
        many(TipsterAngle.contrarian).any((p) => p.contains('fading')),
        isTrue,
      );
      expect(
        many(TipsterAngle.straight).any((p) => p.contains('just value')),
        isTrue,
      );
    });

    test('mentions the weather when there is weather to mention', () {
      List<String> many(Weather weather) => <String>[
        for (var s = 0; s < 40; s++) post(weather: weather, seed: s),
      ];
      expect(many(Weather.rain).any((p) => p.contains('wet pitch')), isTrue);
      expect(many(Weather.storm).any((p) => p.contains('wind')), isTrue);
      expect(many(Weather.clear).any((p) => p.contains('no excuses')), isTrue);
    });

    test('fills the placeholders in every combination', () {
      // A stray {other} or {side} in a post is a template bug the player
      // would see, so this sweeps the whole space rather than sampling it.
      for (final angle in TipsterAngle.values) {
        for (final weather in Weather.values) {
          for (final selection in Selection.values) {
            for (final confidence in <double>[0.2, 0.65, 0.95]) {
              for (var seed = 0; seed < 6; seed++) {
                final text = post(
                  angle: angle,
                  confidence: confidence,
                  selection: selection,
                  weather: weather,
                  seed: seed,
                );
                expect(text, isNot(contains('{')), reason: '$angle $weather');
                expect(text.trim(), isNotEmpty);
              }
            }
          }
        }
      }
    });
  });
}
