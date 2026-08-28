/// The engine's own random number generator, in exact 32-bit arithmetic.
///
/// Two constraints force this design, and both were verified empirically
/// rather than assumed:
///
/// 1. `dart:math`'s [Random] does not document its sequence as a stable
///    contract. Saves are a seed plus event deltas, so the save file is a
///    promise that a seed replays to a season; an SDK upgrade could silently
///    void every existing save. Owning the generator makes that structural.
///
/// 2. The app ships to Android (64-bit ints) AND to a Chrome-wrapped web build
///    (JavaScript numbers: IEEE doubles, exact only to 53 bits). A 64-bit
///    generator does not merely lose precision on the web -- `dart compile js`
///    refuses the literals outright. Every value here therefore stays inside
///    32 bits, and `_mul32` splits its operand so no intermediate product
///    exceeds 2^48. Confirmed byte-identical on the VM and under Node.
///
/// Cross-platform determinism is not a nicety: a save must replay the same way
/// on the phone and on the desktop, or syncing one is meaningless.
library;

/// Truncates [value] to an unsigned 32-bit integer.
int u32(int value) => value & 0xFFFFFFFF;

/// Multiplies two 32-bit values, exactly, on every platform.
///
/// A direct `a * b` can reach 2^64 and loses precision under JavaScript. By
/// splitting [a] into 16-bit halves, the largest intermediate is 2^16 * 2^32 =
/// 2^48, comfortably inside the 53 bits a double represents exactly.
int mul32(int a, int b) {
  final lo = a & 0xFFFF;
  final hi = (a >> 16) & 0xFFFF;
  return u32(u32(lo * b) + u32(u32(hi * b) << 16));
}

/// Advances [state] one step and returns the next raw 32-bit value.
///
/// A linear congruential step (Numerical Recipes constants) feeds an
/// MurmurHash3 finalizer, which decorrelates the low bits an LCG leaves weak.
///
/// Pure: callers thread the state themselves, which is what lets a match be
/// replayed from a sub-seed without touching any global.
({int state, int value}) mix32Next(int state) {
  final next = u32(mul32(state, 1664525) + 1013904223);
  var z = next;
  z = u32(z ^ (z >>> 15));
  z = mul32(z, 2246822519);
  z = u32(z ^ (z >>> 13));
  z = mul32(z, 3266489917);
  return (state: next, value: u32(z ^ (z >>> 16)));
}

/// Renders the 32 bits of [value] as fixed-width hex, for frozen literals.
String hex32(int value) => u32(value).toRadixString(16).padLeft(8, '0');
