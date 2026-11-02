// Exact unbounded allocation. Search storage depends on the number of distinct
// capacities, never on target units or the number of bottles in the result.
List<int>? minimumBottleCounts(int target, List<int> capacities) {
  if (target < 0) throw ArgumentError.value(target, 'target');
  final firstIndices = <int, int>{};
  for (var index = 0; index < capacities.length; index++) {
    final capacity = capacities[index];
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacities[$index]');
    }
    if (capacity <= target && !firstIndices.containsKey(capacity)) {
      firstIndices[capacity] = index;
    }
  }
  final counts = List<int>.filled(capacities.length, 0);
  if (target == 0) return counts;
  if (firstIndices.isEmpty) return null;

  var divisor = firstIndices.keys.first;
  for (final capacity in firstIndices.keys) {
    divisor = divisor.gcd(capacity);
  }
  if (target % divisor != 0) return null;
  final amount = target ~/ divisor;
  final choices = [
    for (final entry in firstIndices.entries)
      (volume: entry.key ~/ divisor, index: entry.value),
  ]..sort((left, right) => right.volume.compareTo(left.volume));
  final largest = choices.first;
  if (amount % largest.volume == 0) {
    counts[largest.index] = amount ~/ largest.volume;
    return counts;
  }
  if (choices.length == 1) return null;

  final suffixGcd = List<int>.filled(choices.length, 0);
  suffixGcd.last = choices.last.volume;
  for (var index = choices.length - 2; index >= 0; index--) {
    suffixGcd[index] = choices[index].volume.gcd(suffixGcd[index + 1]);
  }
  // At a branch, only x satisfying volume*x == remaining (mod suffixGcd)
  // can leave a representable suffix. Precompute its progression once.
  final branchDivisors = <int>[];
  final periods = <int>[];
  final inverses = <int>[];
  for (var index = 0; index < choices.length - 1; index++) {
    final common = choices[index].volume.gcd(suffixGcd[index + 1]);
    final period = suffixGcd[index + 1] ~/ common;
    branchDivisors.add(common);
    periods.add(period);
    inverses.add(_modularInverse(choices[index].volume ~/ common, period));
  }

  List<int>? best;
  int? bestSize;

  void retain(int size) {
    final previousSize = bestSize;
    if (previousSize != null) {
      if (size > previousSize) return;
      if (size == previousSize) {
        final previous = best!;
        var preferred = false;
        for (var index = 0; index < counts.length; index++) {
          if (counts[index] == previous[index]) continue;
          preferred = counts[index] > previous[index];
          break;
        }
        if (!preferred) return;
      }
    }
    bestSize = size;
    best = List<int>.of(counts);
  }

  // Pair solutions cheaply seed a useful upper bound even when a greedy
  // largest-bottle choice would leave an impossible remainder.
  if (choices.length > 2) {
    for (var first = 0; first < choices.length - 1; first++) {
      final larger = choices[first];
      for (var second = first + 1; second < choices.length; second++) {
        final smaller = choices[second];
        final common = larger.volume.gcd(smaller.volume);
        if (amount % common != 0) continue;
        final period = smaller.volume ~/ common;
        final inverse = _modularInverse(larger.volume ~/ common, period);
        final count = _largestCongruentCount(
            amount, larger.volume, common, period, inverse);
        if (count == null) continue;
        final other = (amount - count * larger.volume) ~/ smaller.volume;
        counts[larger.index] = count;
        counts[smaller.index] = other;
        retain(count + other);
        counts[larger.index] = 0;
        counts[smaller.index] = 0;
      }
    }
  }

  void search(int index, int remaining, int used) {
    if (remaining == 0) {
      retain(used);
      return;
    }
    final choice = choices[index];
    final limit = bestSize;
    if (limit != null && used + _ceilDivide(remaining, choice.volume) > limit) {
      return;
    }
    if (index == choices.length - 1) {
      if (remaining % choice.volume != 0) return;
      final count = remaining ~/ choice.volume;
      counts[choice.index] = count;
      retain(used + count);
      counts[choice.index] = 0;
      return;
    }
    final firstCount = _largestCongruentCount(remaining, choice.volume,
        branchDivisors[index], periods[index], inverses[index]);
    if (firstCount == null) return;
    final next = choices[index + 1];
    if (index == choices.length - 2) {
      // For a*x + b*y = remaining with a>b, maximizing feasible x strictly
      // minimizes x+y. One modular solution replaces a scan over all counts.
      final other = (remaining - firstCount * choice.volume) ~/ next.volume;
      counts[choice.index] = firstCount;
      counts[next.index] = other;
      retain(used + firstCount + other);
      counts[choice.index] = 0;
      counts[next.index] = 0;
      return;
    }
    for (var count = firstCount; count >= 0;) {
      final rest = remaining - count * choice.volume;
      final currentBest = bestSize;
      if (currentBest != null &&
          used + count + _ceilDivide(rest, next.volume) > currentBest) {
        // Lowering count replaces a larger bottle with smaller ones, so this
        // lower bound cannot improve for any later count in the progression.
        break;
      }
      counts[choice.index] = count;
      search(index + 1, rest, used + count);
      counts[choice.index] = 0;
      if (count < periods[index]) break;
      count -= periods[index];
    }
  }

  search(0, amount, 0);
  return best;
}

int _ceilDivide(int amount, int capacity) =>
    amount ~/ capacity + (amount % capacity == 0 ? 0 : 1);

int? _largestCongruentCount(
    int remaining, int capacity, int divisor, int period, int inverse) {
  if (remaining % divisor != 0) return null;
  final residue = period == 1
      ? 0
      : _modularProduct(remaining ~/ divisor % period, inverse, period);
  final maximum = remaining ~/ capacity;
  if (residue > maximum) return null;
  return maximum - (maximum - residue) % period;
}

int _modularInverse(int value, int modulus) {
  if (modulus == 1) return 0;
  var previous = 0;
  var current = 1;
  var remainder = modulus;
  var next = value % modulus;
  while (next != 0) {
    final quotient = remainder ~/ next;
    final nextRemainder = remainder % next;
    remainder = next;
    next = nextRemainder;
    final coefficient = previous - quotient * current;
    previous = current;
    current = coefficient;
  }
  return previous % modulus;
}

int _modularProduct(int left, int right, int modulus) {
  if (left == 0 || right == 0) return 0;
  // Keep both native int overflow and JavaScript integer rounding out of
  // modular arithmetic. Small products take the ordinary constant-time path.
  const largestExactProduct = 9007199254740991;
  if (left <= largestExactProduct ~/ right) return left * right % modulus;
  var product = 0;
  while (right > 0) {
    if (right.isOdd) {
      final gap = modulus - left;
      product = product >= gap ? product - gap : product + left;
    }
    right ~/= 2;
    if (right != 0) {
      final gap = modulus - left;
      left = left >= gap ? left - gap : left + left;
    }
  }
  return product;
}
