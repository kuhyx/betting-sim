import 'package:betting_sim/state/cards.dart';
import 'package:betting_sim/state/friends.dart';
import 'package:betting_sim/state/game.dart';
import 'package:betting_sim/state/save.dart';

/// Writing a running game down.
///
/// An extension rather than a method on `GameState` so that persistence lives
/// beside the format it produces, and so the controller stays a controller.
/// It needs nothing private: a save is the seed, the knobs, how far in, and
/// the settled bets, all of which are already public because the UI shows
/// them.
extension GameSave on GameState {
  /// The save that would restore this game.
  SaveData toSave() => SaveData(
    masterSeed: masterSeed,
    tuning: tuning,
    day: day,
    // `history` is newest-first for the results list; a save is a log, so it
    // goes back the other way.
    bets: List<PlayerBet>.of(history.reversed),
    peerBets: List<PeerBet>.of(peerHistory.reversed),
  );
}
