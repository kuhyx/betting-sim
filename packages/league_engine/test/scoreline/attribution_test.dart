import 'package:league_engine/league_engine.dart';
import 'package:test/test.dart';

Player _player(
  int id, {
  double attack = 50,
  double defence = 50,
  double stamina = 60,
}) => Player(
  id: id,
  name: 'p$id',
  attack: attack,
  defence: defence,
  stamina: stamina,
  age: 25,
);

const _empty = TeamSheet(starting: <Player>[], missing: <Player>[]);

TeamSheet _sheet(List<Player> starting) =>
    TeamSheet(starting: starting, missing: const <Player>[]);

void main() {
  group('attributeGoals', () {
    final home = _sheet(<Player>[_player(1, attack: 100)]);
    final away = _sheet(<Player>[_player(2, attack: 100)]);

    test('names a scorer without moving the goal', () {
      // GoalEvent.playerId has been nullable and always null since the type
      // was written. The minute and the side must survive untouched: they
      // came from the scoreline model, which the narrator may not disturb.
      final named = attributeGoals(
        goals: <GoalEvent>[
          const GoalEvent(minute: 12, byHome: true, playerId: null),
          const GoalEvent(minute: 71, byHome: false, playerId: null),
        ],
        homeSheet: home,
        awaySheet: away,
        rng: ScriptedRandomSource(uniforms: <double>[0.5, 0.5]),
      );

      expect(named.map((g) => g.minute), <int>[12, 71]);
      expect(named.map((g) => g.byHome), <bool>[true, false]);
      expect(named.map((g) => g.playerId), <int>[1, 2]);
    });

    test('leaves the scorer unnamed when nobody was available', () {
      final named = attributeGoals(
        goals: <GoalEvent>[
          const GoalEvent(minute: 5, byHome: true, playerId: null),
        ],
        homeSheet: _empty,
        awaySheet: away,
        rng: ScriptedRandomSource(),
      );
      expect(named.single.playerId, isNull);
    });

    test('favours the attackers', () {
      final squad = _sheet(<Player>[
        _player(0, attack: 1),
        _player(1, attack: 99),
      ]);
      var striker = 0;
      for (var i = 0; i < 500; i++) {
        final named = attributeGoals(
          goals: <GoalEvent>[
            const GoalEvent(minute: 1, byHome: true, playerId: null),
          ],
          homeSheet: squad,
          awaySheet: squad,
          rng: Mix32Source(i),
        );
        if (named.single.playerId == 1) {
          striker++;
        }
      }
      expect(striker, greaterThan(450));
    });
  });

  group('attributeCards', () {
    final sheet = _sheet(<Player>[_player(3, defence: 100)]);

    test('issues the reds first, then the yellows', () {
      final cards = attributeCards(
        homeSide: true,
        yellows: 1,
        reds: 1,
        sheet: sheet,
        rng: ScriptedRandomSource(
          uniforms: <double>[0.5, 0.5],
          ints: <int>[30, 60],
        ),
      );

      expect(cards, hasLength(2));
      expect(cards[0], isA<RedCardEvent>());
      expect(cards[0].minute, 30);
      expect(cards[1], isA<YellowCardEvent>());
      expect(cards[1].minute, 60);
      expect((cards[1] as YellowCardEvent).playerId, 3);
      expect((cards[1] as YellowCardEvent).homeSide, isTrue);
    });

    test('shows no cards when there were none', () {
      expect(
        attributeCards(
          homeSide: false,
          yellows: 0,
          reds: 0,
          sheet: sheet,
          rng: ScriptedRandomSource(),
        ),
        isEmpty,
      );
    });

    test('cannot book a side with nobody on the pitch', () {
      expect(
        attributeCards(
          homeSide: true,
          yellows: 2,
          reds: 1,
          sheet: _empty,
          rng: ScriptedRandomSource(uniforms: <double>[0, 0, 0]),
        ),
        isEmpty,
      );
    });
  });

  group('attributeInjury', () {
    test('hurts the player least able to last', () {
      final sheet = _sheet(<Player>[
        _player(0, stamina: 104),
        _player(1, stamina: 5),
      ]);
      var weak = 0;
      for (var i = 0; i < 400; i++) {
        final hurt = attributeInjury(
          homeSide: true,
          sheet: sheet,
          config: const NarrationConfig(),
          rng: Mix32Source(i),
        );
        if (hurt!.playerId == 1) {
          weak++;
        }
      }
      expect(weak, greaterThan(370));
    });

    test('returns nothing when there is nobody left to hurt', () {
      expect(
        attributeInjury(
          homeSide: false,
          sheet: _empty,
          config: const NarrationConfig(),
          rng: ScriptedRandomSource(),
        ),
        isNull,
      );
    });
  });

  group('inMatchOrder', () {
    test('sorts by minute', () {
      final sorted = inMatchOrder(<MatchEvent>[
        const GoalEvent(minute: 80, byHome: true, playerId: 1),
        const YellowCardEvent(minute: 10, homeSide: true, playerId: 2),
        const RedCardEvent(minute: 45, homeSide: false, playerId: 3),
      ]);
      expect(sorted.map((e) => e.minute), <int>[10, 45, 80]);
    });

    test('keeps same-minute events in the order they were built', () {
      // List.sort is not stable in Dart, so without the index tie-break the
      // VM and JavaScript could disagree -- which check_rng_parity.sh forbids.
      final sorted = inMatchOrder(<MatchEvent>[
        const GoalEvent(minute: 45, byHome: true, playerId: 1),
        const YellowCardEvent(minute: 45, homeSide: true, playerId: 2),
        const RedCardEvent(minute: 45, homeSide: false, playerId: 3),
      ]);
      expect(sorted[0], isA<GoalEvent>());
      expect(sorted[1], isA<YellowCardEvent>());
      expect(sorted[2], isA<RedCardEvent>());
    });

    test('handles an empty match', () {
      expect(inMatchOrder(<MatchEvent>[]), isEmpty);
    });
  });

  group('event rendering', () {
    test('each event says what it was', () {
      expect(
        const YellowCardEvent(
          minute: 9,
          homeSide: true,
          playerId: 1,
        ).toString(),
        "Yellow(H 9')",
      );
      expect(
        const YellowCardEvent(
          minute: 9,
          homeSide: false,
          playerId: 1,
        ).toString(),
        "Yellow(A 9')",
      );
    });
  });
}
