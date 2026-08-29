import 'package:shared_preferences/shared_preferences.dart';

/// Where a save lives between launches.
///
/// An interface rather than a direct `shared_preferences` call so the state
/// layer can be driven in tests without a platform channel, and so the
/// storage backend can change without the game knowing.
abstract interface class SaveStore {
  /// Returns the stored save, or null if there is none.
  Future<String?> read();

  /// Overwrites the stored save with [raw].
  Future<void> write(String raw);

  /// Removes the stored save.
  Future<void> clear();
}

/// The shipping [SaveStore]: `shared_preferences`, which is `localStorage`
/// on the Chrome-wrapped web build and a real file on Android.
class PrefsSaveStore implements SaveStore {
  /// Creates a store, optionally over an existing [preferences] instance.
  PrefsSaveStore({SharedPreferencesAsync? preferences})
    : _prefs = preferences ?? SharedPreferencesAsync();

  /// The key the save is written under.
  static const String key = 'betting_sim.save.v1';

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(key);

  @override
  Future<void> write(String raw) => _prefs.setString(key, raw);

  @override
  Future<void> clear() => _prefs.remove(key);
}

/// An in-memory [SaveStore] for tests and for the debug tuning panel, which
/// restarts the season constantly and must not scribble over a real save.
class MemorySaveStore implements SaveStore {
  /// Creates an empty store, or one already holding [raw].
  MemorySaveStore([this._raw]);

  String? _raw;

  /// What is currently stored, without awaiting.
  String? get raw => _raw;

  @override
  Future<String?> read() async => _raw;

  @override
  Future<void> write(String raw) async => _raw = raw;

  @override
  Future<void> clear() async => _raw = null;
}
