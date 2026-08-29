import 'package:league_engine/src/league/name_corpus.dart';
import 'package:league_engine/src/league/names.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';

/// The seed-tree slot the circle of friends is generated from.
///
/// Social owns 30-39. Append-only, like every other slot.
const int friendCircleSlot = 30;

/// The slot one fixture's proposals are drawn from.
const int proposalSlot = 31;

/// What somebody always ends up backing, whatever the fixture.
enum FriendBias {
  /// Backs whoever is favourite. Most people, most of the time.
  chalk,

  /// Backs the big price, because it pays more.
  longshot,

  /// Backs one club regardless, forever.
  loyal,

  /// Backs the draw far more often than anyone should.
  cagey,
}

/// Somebody you know, who wants a bet on it.
///
/// Not a bookmaker: a friend offers you a price they think is fair BY THEIR
/// OWN LIGHTS, with no margin in it. That is what makes accepting everything
/// a wash rather than a slow bleed, and what makes choosing WHICH to accept
/// the entire game. Gate 5 asserts both halves.
class Friend {
  /// Creates a friend.
  const Friend({
    required this.id,
    required this.name,
    required this.awareness,
    required this.noise,
    required this.bias,
    required this.loyalClubId,
    required this.chattiness,
    required this.stubbornness,
  });

  /// Stable identity within a save.
  final int id;

  /// What you call them.
  final String name;

  /// How far their opinion sits off the price, toward the truth.
  ///
  /// Near zero for almost everybody: these are your mates, not sharps. A
  /// friend above zero is somebody whose bets you should mostly decline.
  final double awareness;

  /// The scale of their random error, in LOG-ODDS.
  ///
  /// This is where your edge against them comes from. A friend who is
  /// unbiased but NOISY offers you a fair price on average and a wrong one
  /// often, and taking only the wrong ones is the whole skill.
  ///
  /// Log-odds rather than probability, because you are LAYING their pick: a
  /// long price is where your money is, and additive noise would distort
  /// exactly those prices hardest. See `perturbLogOdds`.
  final double noise;

  /// What they always end up backing.
  final FriendBias bias;

  /// The club they will back until they die. Only meaningful for
  /// [FriendBias.loyal].
  final int loyalClubId;

  /// How often they bother proposing anything, 0..1.
  final double chattiness;

  /// How far they will move if you counter, 0..1.
  ///
  /// Zero means take it or leave it. High means they will talk themselves
  /// into a bad price, which is worth knowing about a person.
  final double stubbornness;

  @override
  String toString() => 'Friend($name)';
}

/// How many friends a save has, and how varied they are.
class FriendCircleConfig {
  /// Creates a circle shape.
  const FriendCircleConfig({
    this.count = 6,
    this.awareness = (low: -0.06, high: 0.04),
    this.noise = (low: 0.18, high: 0.55),
    this.chattiness = (low: 0.12, high: 0.45),
    this.stubbornness = (low: 0, high: 0.6),
  });

  /// How many people you know who want a bet.
  final int count;

  /// How far off the price they sit. Centred near zero and slightly
  /// pessimistic: your friends are, on the whole, not very good at this.
  final ({double low, double high}) awareness;

  /// How wrong they are match to match. Your edge lives here.
  final ({double low, double high}) noise;

  /// How talkative they are.
  final ({double low, double high}) chattiness;

  /// How far they will move on a counter-offer.
  final ({double low, double high}) stubbornness;
}

/// Builds the circle of friends a save is stuck with.
List<Friend> generateFriends(
  int masterSeed,
  List<int> clubIds, [
  FriendCircleConfig config = const FriendCircleConfig(),
]) {
  final rng = Mix32Source(
    deriveSeed(SeedPath(master: masterSeed, possession: friendCircleSlot)),
  );
  final namer = MarkovNamer(forenameCorpus);
  final biases = _biases(config.count, rng);
  return <Friend>[
    for (var i = 0; i < config.count; i++)
      Friend(
        id: i,
        name: namer.generate(rng),
        awareness: _in(config.awareness, rng),
        noise: _in(config.noise, rng),
        bias: biases[i],
        loyalClubId: clubIds.isEmpty
            ? -1
            : clubIds[rng.randint(0, clubIds.length - 1)],
        chattiness: _in(config.chattiness, rng),
        stubbornness: _in(config.stubbornness, rng),
      ),
  ];
}

/// One of each type first, then free choice, then shuffled.
///
/// Guaranteed rather than hoped for. Drawing each bias independently is
/// uniform ACROSS saves and lopsided WITHIN one -- seed 20260828 produced four
/// cagey friends and two who chased favourites, so three quarters of the
/// circle only ever wanted the draw. A circle that always contains one of each
/// makes the mechanic legible, and stops a save being quietly unplayable
/// because everybody you know has the same idea.
List<FriendBias> _biases(int count, RandomSource rng) {
  final biases = <FriendBias>[
    for (var i = 0; i < count; i++)
      if (i < FriendBias.values.length)
        FriendBias.values[i]
      else
        FriendBias.values[rng.randint(0, FriendBias.values.length - 1)],
  ];
  for (var i = biases.length - 1; i > 0; i--) {
    final j = rng.randint(0, i);
    final swap = biases[i];
    biases[i] = biases[j];
    biases[j] = swap;
  }
  return biases;
}

double _in(({double low, double high}) range, RandomSource rng) =>
    range.low + rng.uniform01() * (range.high - range.low);
