import 'dart:convert';

import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/tuning.dart';
import 'package:league_engine/league_engine.dart';

/// The save format's version. Bumped whenever the shape below changes.
///
/// 2 added the friend bets. A version 1 save would have been rejected anyway,
/// by failing to parse -- but silently relying on that would make the number
/// a lie, and the next change might not be so obliging.
const int saveVersion = 2;

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
    required this.peerBets,
  });

  /// The root seed the season was generated from.
  final int masterSeed;

  /// The balance knobs the season was priced under.
  final Tuning tuning;

  /// How many matchdays have been played.
  final int day;

  /// Every settled bet against the book, oldest first.
  final List<PlayerBet> bets;

  /// Every settled bet against a friend, oldest first.
  ///
  /// Stored rather than replayed, because a handshake is a CHOICE. The
  /// fixtures, the odds and the scorelines all come back from the seed, but
  /// nothing in the seed knows which offers you took.
  final List<PeerBet> peerBets;

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
    'peerBets': peerBets.map(_peerToJson).toList(),
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
      final peers = json['peerBets']! as List<dynamic>;
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
        peerBets: <PeerBet>[
          for (final bet in peers) _peerFromJson(bet! as Map<String, dynamic>),
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

Map<String, dynamic> _peerToJson(PeerBet bet) => <String, dynamic>{
  'friendId': bet.friendId,
  'name': bet.name,
  'fixture': bet.fixture,
  'selection': bet.selection.name,
  'stake': bet.stake,
  'odds': bet.odds.decimal,
  'profit': bet.profit,
  'result': bet.result,
  'haggled': bet.haggled,
};

PeerBet _peerFromJson(Map<String, dynamic> json) => PeerBet(
  friendId: json['friendId']! as int,
  name: json['name']! as String,
  fixture: json['fixture']! as String,
  selection: Selection.values.byName(json['selection']! as String),
  stake: json['stake']! as double,
  odds: Odds(json['odds']! as double),
  profit: json['profit']! as double,
  result: json['result']! as String,
  haggled: json['haggled']! as bool,
);
