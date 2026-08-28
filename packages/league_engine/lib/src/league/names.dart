import 'package:league_engine/src/rng/source.dart';

/// Generates invented place and person names with an order-2 Markov chain.
///
/// Order 2 is the sweet spot found in name-generator practice: order 1 produces
/// mush, and order 3+ mostly regurgitates the training corpus. Names that are
/// verbatim corpus entries are rejected, so the league never fields a town that
/// exists.
///
/// The sport, its teams and its towns are fictional on purpose -- this is a
/// fake-stock-market simulator, not a licensed league.
class MarkovNamer {
  /// Builds a namer from [corpus].
  MarkovNamer(List<String> corpus)
    : _corpus = corpus.map((s) => s.toLowerCase()).toSet() {
    for (final raw in corpus) {
      final word = '^^${raw.toLowerCase()}\$';
      for (var i = 0; i + 2 < word.length; i++) {
        _chain
            .putIfAbsent(word.substring(i, i + 2), () => <String>[])
            .add(
              word[i + 2],
            );
      }
    }
  }

  final Set<String> _corpus;
  final Map<String, List<String>> _chain = <String, List<String>>{};

  /// Generates one name of length [minLength]..[maxLength].
  ///
  /// Falls back to a corpus-derived blend if the chain wanders into a dead end
  /// or keeps producing real names; the caller always gets a usable string.
  String generate(
    RandomSource rng, {
    int minLength = 4,
    int maxLength = 11,
    int attempts = 24,
  }) {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final candidate = _walk(rng, maxLength);
      if (candidate.length >= minLength &&
          candidate.length <= maxLength &&
          !_corpus.contains(candidate)) {
        return _capitalise(candidate);
      }
    }
    return _capitalise(_blend(rng, minLength, maxLength));
  }

  /// Walks the chain to a natural ending, or returns '' if it ran too long.
  ///
  /// Returning empty on overrun matters: truncating at [maxLength] instead
  /// yields names chopped mid-syllable ("Kestonebrid", "Barsterhitm"), which
  /// read as bugs. A rejected walk simply costs another attempt.
  String _walk(RandomSource rng, int maxLength) {
    var state = '^^';
    final out = StringBuffer();
    while (out.length <= maxLength) {
      final options = _chain[state];
      if (options == null || options.isEmpty) {
        return '';
      }
      final next = options[rng.randint(0, options.length - 1)];
      if (next == r'$') {
        return out.toString();
      }
      out.write(next);
      state = '${state[1]}$next';
    }
    return '';
  }

  /// Splices the front of one corpus name onto the back of another.
  ///
  /// Only used when the chain fails repeatedly, which happens with a small or
  /// very uniform corpus.
  String _blend(RandomSource rng, int minLength, int maxLength) {
    final words = _corpus.toList();
    final a = words[rng.randint(0, words.length - 1)];
    final b = words[rng.randint(0, words.length - 1)];
    final head = a.substring(0, (a.length / 2).ceil());
    final tail = b.substring(b.length ~/ 2);
    final joined = '$head$tail';
    if (joined.length < minLength) {
      return joined.padRight(minLength, 'a');
    }
    return joined.length > maxLength ? joined.substring(0, maxLength) : joined;
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
