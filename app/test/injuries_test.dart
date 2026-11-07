import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/game_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who is out on each of the first [rounds] cards, club id to count.
List<Map<int, int>> _injuries(GameState game, int rounds) {
  final seen = <Map<int, int>>[];
  for (var r = 0; r < rounds; r++) {
    seen.add(_outNow(game));
    game.advanceDay();
  }
  return seen;
}

Map<int, int> _outNow(GameState game) => <int, int>{
  for (final card in game.fixtures) ...<int, int>{
    card.home.id: card.context.homeModifiers.missingCount,
    card.away.id: card.context.awayModifiers.missingCount,
  },
};

void main() {
  group('injuries in the app', () {
    test('within six rounds somebody is out, and later comes back', () {
      final seen = _injuries(GameState(), 20);
      expect(seen.take(7).any((day) => day.values.any((n) => n > 0)), isTrue);

      final recovered = <bool>[
        for (var r = 1; r < seen.length; r++)
          for (final id in seen[r].keys)
            if (seen[r][id]! < seen[r - 1][id]!) true,
      ];
      expect(recovered, isNotEmpty, reason: 'nobody ever returned');
    });

    test('the same seed injures the same clubs on the same days', () {
      expect(_injuries(GameState(), 12), _injuries(GameState(), 12));
    });

    test('a save brings the same injuries back', () {
      final original = GameState();
      for (var i = 0; i < 9; i++) {
        original.advanceDay();
      }
      final restored = GameState.fromSave(original.toSave());
      expect(_outNow(restored), _outNow(original));
      expect(restored.bankroll, original.bankroll);
    });
  });
}
