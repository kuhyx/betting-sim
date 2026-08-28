import 'package:league_engine/src/rng/source.dart';

/// A [RandomSource] that returns a pre-written sequence of draws.
///
/// Shipped in `lib/`, not `test/`, deliberately: it is the primary tool for
/// reaching rare branches (injury, red card, the exactly-zero CLV boundary)
/// deterministically and with no seed search, so it is production-grade code
/// that must itself be covered.
///
/// Each accessor consumes from its own queue, so a test can script an injury
/// roll without also having to supply every unrelated uniform draw.
class ScriptedRandomSource implements RandomSource {
  /// Creates a source that replays the given queues in order.
  ScriptedRandomSource({
    List<double>? uniforms,
    List<int>? ints,
    List<double>? normals,
    List<int>? poissons,
  }) : _uniforms = List<double>.of(uniforms ?? const <double>[]),
       _ints = List<int>.of(ints ?? const <int>[]),
       _normals = List<double>.of(normals ?? const <double>[]),
       _poissons = List<int>.of(poissons ?? const <int>[]);

  final List<double> _uniforms;
  final List<int> _ints;
  final List<double> _normals;
  final List<int> _poissons;

  int _uniformAt = 0;
  int _intAt = 0;
  int _normalAt = 0;
  int _poissonAt = 0;

  static T _take<T>(List<T> queue, int at, String name) {
    if (at >= queue.length) {
      throw StateError(
        'ScriptedRandomSource: $name queue exhausted after ${queue.length} '
        'draw(s). The code under test consumed more randomness than the test '
        'scripted -- extend the queue rather than padding it blindly.',
      );
    }
    return queue[at];
  }

  @override
  double uniform01() => _take(_uniforms, _uniformAt++, 'uniform01');

  @override
  int randint(int low, int high) => _take(_ints, _intAt++, 'randint');

  @override
  double normal(double mu, double sigma) =>
      _take(_normals, _normalAt++, 'normal');

  @override
  int poisson(double lambda) => _take(_poissons, _poissonAt++, 'poisson');
}
