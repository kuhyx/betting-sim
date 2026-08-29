import 'dart:convert';

import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:league_engine/league_engine.dart';

/// The save format's version. Bumped whenever the shape below changes.
const int saveVersion = 1;

/// A save: a seed, the knobs it was struck under, how far in it is, and every
/// bet that has settled.
///
/// Deliberately NOT a snapshot of the league. Per `DOCS-architecture.md` a
/// save is a master seed plus deltas: the fixtures, the hidden state and every
/// scoreline are all recoverable by replaying [day] matchdays from
/// [masterSeed], so none of them is written down. The bankroll is not stored
/// either -- it is the opening balance plus the profits below, and writing
/// down a derivable number is exactly how two copies of it come to disagree.
class SaveData {
  /// Creates a save.
  const SaveData({
    required this.masterSeed,
    required this.tuning,
    required this.day,
    required this.bets,
  });

  /// The root seed the season was generated from.
  final int masterSeed;

  /// The balance knobs the season was priced under.
  final Tuning tuning;

  /// How many matchdays have been played.
  final int day;

  /// Every settled bet, oldest first.
  final List<PlayerBet> bets;

  /// Renders this save as JSON text.
  String encode() => jsonEncode(<String, dynamic>{
    'version': saveVersion,
    'masterSeed': masterSeed,
    'day': day,
    'tuning': <String, dynamic>{
      'bookLatentAwareness': tuning.bookLatentAwareness,
      'strengthScale': tuning.strengthScale,
      'fatigueAttackPenalty': tuning.fatigueAttackPenalty,
      'margin': tuning.margin,
    },
    'bets': bets.map(_betToJson).toList(),
  });

  /// Parses [raw], or returns null if it is missing, corrupt or from a
  /// future version.
  ///
  /// Null rather than an exception on every failure path: a save that cannot
  /// be read must start a new game, never crash the app on launch. A player
  /// losing a season to a bad write is bad; losing the app to one is worse.
  static SaveData? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != saveVersion) {
        return null;
      }
      final tuning = json['tuning']! as Map<String, dynamic>;
      final bets = json['bets']! as List<dynamic>;
      return SaveData(
        masterSeed: json['masterSeed']! as int,
        day: json['day']! as int,
        tuning: Tuning(
          bookLatentAwareness: tuning['bookLatentAwareness']! as double,
          strengthScale: tuning['strengthScale']! as double,
          fatigueAttackPenalty: tuning['fatigueAttackPenalty']! as double,
          margin: tuning['margin']! as double,
        ),
        bets: <PlayerBet>[
          for (final bet in bets) _betFromJson(bet! as Map<String, dynamic>),
        ],
      );
    } on Object {
      // Any malformed field at all: a missing key, a string where a number
      // belongs, a truncated write. All of them mean the same thing here.
      return null;
    }
  }
}

Map<String, dynamic> _betToJson(PlayerBet bet) => <String, dynamic>{
  'fixture': bet.fixture,
  'selection': bet.selection.name,
  'stake': bet.stake,
  'taken': bet.taken.decimal,
  'profit': bet.profit,
  'result': bet.result,
  'clv': bet.closingLineValue,
};

PlayerBet _betFromJson(Map<String, dynamic> json) => PlayerBet(
  fixture: json['fixture']! as String,
  selection: Selection.values.byName(json['selection']! as String),
  stake: json['stake']! as double,
  taken: Odds(json['taken']! as double),
  profit: json['profit']! as double,
  result: json['result']! as String,
  closingLineValue: json['clv']! as double,
);
