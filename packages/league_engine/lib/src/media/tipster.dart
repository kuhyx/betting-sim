import 'package:league_engine/src/league/name_corpus.dart';
import 'package:league_engine/src/league/names.dart';
import 'package:league_engine/src/rng/seeds.dart';
import 'package:league_engine/src/rng/source.dart';

/// The seed-tree slot the panel of tipsters is generated from.
///
/// Media owns 20-29, social 30-39, life 40-49. Append-only, like every other
/// slot: see `DOCS-seeding.md`.
const int tipsterPanelSlot = 20;

/// The slot a single fixture's tips are drawn from.
const int tipSlot = 21;

/// The angle a tipster reliably takes, whatever the fixture.
///
/// A bias is not the same thing as being wrong. A homer who is also sharp can
/// still beat the market; a straight shooter who knows nothing cannot. Keeping
/// the two independent is what stops "which of these people is worth reading"
/// from being answerable at a glance.
enum TipsterAngle {
  /// No systematic lean.
  straight,

  /// Always leans toward the home side.
  homer,

  /// Always leans toward whoever is favourite.
  favourite,

  /// Always leans against the favourite.
  contrarian,
}

/// Somebody on the internet with an opinion about a football match.
///
/// An opinion anchored on the published price and dragged some distance toward
/// the truth. A tipster whose [awareness] is above zero knows something the
/// price does not, and that gap is the only place an edge can come from.
///
/// [confidence] is drawn INDEPENDENTLY of [awareness]. That is the whole
/// mechanic: how loudly somebody states an opinion tells you nothing about
/// whether it is any good, so the only way to find the sharp ones is to keep
/// records.
class Tipster {
  /// Creates a tipster.
  const Tipster({
    required this.id,
    required this.handle,
    required this.awareness,
    required this.noise,
    required this.angle,
    required this.confidence,
  });

  /// Stable identity within a save.
  final int id;

  /// What they post under.
  final String handle;

  /// How far they move from the published price toward the truth.
  ///
  /// Never shown. Zero means they are reading the odds back to you and cannot
  /// beat them; NEGATIVE means they are worse than the price. Only a couple of
  /// people on any panel are meaningfully above zero, and nothing marks which.
  final double awareness;

  /// The scale of their random error, in probability.
  final double noise;

  /// Their standing lean.
  final TipsterAngle angle;

  /// How strongly they state it, 0..1. Uncorrelated with being right.
  final double confidence;

  @override
  String toString() => 'Tipster($handle)';
}

/// How many of each sort of tipster a save has.
class TipsterPanelConfig {
  /// Creates a panel shape.
  const TipsterPanelConfig({
    this.count = 12,
    this.sharpCount = 2,
    this.poorCount = 3,
    this.sharpAwareness = (low: 0.22, high: 0.38),
    this.crowdAwareness = (low: -0.05, high: 0.12),
    this.poorAwareness = (low: -0.25, high: -0.05),
    this.sharpNoise = (low: 0.010, high: 0.020),
    this.crowdNoise = (low: 0.020, high: 0.040),
    this.poorNoise = (low: 0.040, high: 0.070),
    this.confidence = (low: 0.30, high: 1.0),
  });

  /// How many tipsters the save has.
  final int count;

  /// How many of them genuinely know more than the book.
  final int sharpCount;

  /// How many are worse than useless.
  final int poorCount;

  /// Awareness range for the sharp ones: they close a third to a half of the
  /// gap between the price and the truth.
  final ({double low, double high}) sharpAwareness;

  /// Awareness range for the many, who sit on the price and add nothing.
  final ({double low, double high}) crowdAwareness;

  /// Awareness range for the poor ones. NEGATIVE: worse than the odds.
  final ({double low, double high}) poorAwareness;

  /// Error range for the sharp ones.
  final ({double low, double high}) sharpNoise;

  /// Error range for the crowd.
  final ({double low, double high}) crowdNoise;

  /// Error range for the poor ones.
  final ({double low, double high}) poorNoise;

  /// How loudly anyone states anything. Independent of everything above.
  final ({double low, double high}) confidence;
}

/// Builds the panel of tipsters a save is stuck with.
///
/// Deterministic from [masterSeed], like everything else: the same save always
/// has the same people posting, so a record kept over a season is a record of
/// something real rather than of a reshuffled cast.
List<Tipster> generateTipsters(
  int masterSeed, [
  TipsterPanelConfig config = const TipsterPanelConfig(),
]) {
  final rng = Mix32Source(
    deriveSeed(SeedPath(master: masterSeed, possession: tipsterPanelSlot)),
  );
  final namer = MarkovNamer(forenameCorpus);
  final drawn = <Tipster>[
    for (var i = 0; i < config.count; i++) _tipsterAt(i, config, namer, rng),
  ];

  // Shuffle, then renumber. The bands are generated in a fixed order, so
  // without this the two sharp tipsters would always be ids 0 and 1 -- and
  // "follow the first two accounts" would be a winning strategy that required
  // reading nothing. Fisher-Yates, drawn from the same source, so the panel is
  // still identical every time this save is opened.
  for (var i = drawn.length - 1; i > 0; i--) {
    final j = rng.randint(0, i);
    final swap = drawn[i];
    drawn[i] = drawn[j];
    drawn[j] = swap;
  }
  return <Tipster>[
    for (final (i, t) in drawn.indexed)
      Tipster(
        id: i,
        handle: t.handle,
        awareness: t.awareness,
        noise: t.noise,
        angle: t.angle,
        confidence: t.confidence,
      ),
  ];
}

Tipster _tipsterAt(
  int index,
  TipsterPanelConfig config,
  MarkovNamer namer,
  RandomSource rng,
) {
  final sharp = index < config.sharpCount;
  final poor = !sharp && index < config.sharpCount + config.poorCount;

  final awareness = _in(
    sharp
        ? config.sharpAwareness
        : (poor ? config.poorAwareness : config.crowdAwareness),
    rng,
  );
  final noise = _in(
    sharp ? config.sharpNoise : (poor ? config.poorNoise : config.crowdNoise),
    rng,
  );
  // Exactly one confidently-wrong contrarian per save: the first poor one.
  // Everyone else's lean is drawn, so the panel is not a fixed cast list.
  final angle = index == config.sharpCount && poor
      ? TipsterAngle.contrarian
      : _angle(rng);

  return Tipster(
    id: index,
    handle: '@${namer.generate(rng).toLowerCase()}',
    awareness: awareness,
    noise: noise,
    angle: angle,
    confidence: _in(config.confidence, rng),
  );
}

TipsterAngle _angle(RandomSource rng) {
  final roll = rng.uniform01();
  if (roll < 0.25) {
    return TipsterAngle.homer;
  }
  if (roll < 0.5) {
    return TipsterAngle.favourite;
  }
  return TipsterAngle.straight;
}

double _in(({double low, double high}) range, RandomSource rng) =>
    range.low + rng.uniform01() * (range.high - range.low);
