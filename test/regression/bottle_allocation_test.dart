import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/utils/bottle_allocation.dart';

// Deliberately enumerate every original-order count vector. This oracle does
// not sort, normalize, prune by bottle count, or use modular arithmetic.
List<int>? _bruteForce(int target, List<int> capacities) {
  final counts = List<int>.filled(capacities.length, 0);
  List<int>? best;
  var bestSize = target + 1;

  void enumerate(int index, int sum, int size) {
    if (index == capacities.length) {
      if (sum != target) return;
      var preferred = size < bestSize;
      if (size == bestSize && best != null) {
        for (var position = 0; position < counts.length; position++) {
          if (counts[position] == best![position]) continue;
          preferred = counts[position] > best![position];
          break;
        }
      }
      if (preferred) {
        best = List<int>.of(counts);
        bestSize = size;
      }
      return;
    }
    for (var count = 0; sum + count * capacities[index] <= target; count++) {
      counts[index] = count;
      enumerate(index + 1, sum + count * capacities[index], size + count);
    }
    counts[index] = 0;
  }

  enumerate(0, 0, 0);
  return best;
}

void main() {
  test('zero target preserves the original number of capacity positions', () {
    expect(minimumBottleCounts(0, []), <int>[]);
    expect(minimumBottleCounts(0, [4, 7, 4]), [0, 0, 0]);
  });

  test('impossible targets return null without approximate filling', () {
    expect(minimumBottleCounts(1, []), isNull);
    expect(minimumBottleCounts(7, [4, 6]), isNull);
    expect(minimumBottleCounts(7, [4, 10]), isNull);
    expect(minimumBottleCounts(1999967, [999983, 1000000]), isNull);
  });

  test('unsorted capacities retain original count positions without mutation',
      () {
    final capacities = [9, 6, 5];
    expect(minimumBottleCounts(12, capacities), [0, 2, 0]);
    expect(capacities, [9, 6, 5]);
    expect(minimumBottleCounts(8, [5, 3]), [1, 1]);
  });

  test('duplicate capacities assign every chosen bottle to the earliest index',
      () {
    expect(minimumBottleCounts(8, [4, 6, 4]), [2, 0, 0]);
    expect(minimumBottleCounts(1, [2, 1, 1]), [0, 1, 0]);
  });

  test('fewest bottles precedes the earlier-capacity tie preference', () {
    expect(minimumBottleCounts(10, [2, 3, 5]), [0, 0, 2]);
    expect(minimumBottleCounts(31, [6, 10, 15]), [1, 1, 1]);
  });

  test('equal minima maximize original counts lexicographically', () {
    expect(minimumBottleCounts(12, [4, 6, 8]), [1, 0, 1]);
    expect(minimumBottleCounts(12, [6, 4, 8]), [2, 0, 0]);
    expect(minimumBottleCounts(12, [8, 4, 6]), [1, 1, 0]);
    expect(minimumBottleCounts(15, [4, 5, 6]), [1, 1, 1]);
    expect(minimumBottleCounts(14, [20, 4, 6, 8]), [0, 0, 1, 1]);
  });

  test('scaled six-decimal capacities remain exact', () {
    expect(minimumBottleCounts(4750010, [475001, 333333]), [10, 0]);
    expect(minimumBottleCounts(4750010, [333333, 475001]), [0, 10]);
    expect(minimumBottleCounts(100000, [475001, 333333]), isNull);
  });

  test('huge two-capacity counts are solved without a count scan', () {
    expect(minimumBottleCounts(1000000000001, [3, 2]), [333333333333, 1]);
    expect(minimumBottleCounts(1000000000001, [2, 3]), [1, 333333333333]);
    // The modular multiplication would overflow signed 64-bit integers even
    // though this exact input and result fit JS-safe integers.
    expect(
        minimumBottleCounts(1507000000007049, [1500000000007, 1000000000007]),
        [1000, 7]);
  });

  test('huge allocations requiring every capacity use exact sparse pruning',
      () {
    expect(
        minimumBottleCounts(1000000000001, [6, 10, 15]), [1, 2, 66666666665]);
  });

  test('positive-capacity and nonnegative-target preconditions are explicit',
      () {
    expect(() => minimumBottleCounts(-1, [1]), throwsArgumentError);
    expect(() => minimumBottleCounts(1, [0, 1]), throwsArgumentError);
    expect(() => minimumBottleCounts(1, [-1, 1]), throwsArgumentError);
  });

  test('matches independent exhaustive enumeration for small ordered triples',
      () {
    for (var first = 1; first <= 6; first++) {
      for (var second = 1; second <= 6; second++) {
        for (var third = 1; third <= 6; third++) {
          final capacities = [first, second, third];
          for (var target = 0; target <= 24; target++) {
            expect(
              minimumBottleCounts(target, capacities),
              _bruteForce(target, capacities),
              reason: 'target=$target capacities=$capacities',
            );
          }
        }
      }
    }
  });

  test('matches independent exhaustive enumeration with four capacities', () {
    for (var sample = 0; sample < 120; sample++) {
      final capacities = [
        1 + sample % 9,
        1 + (sample * 7 + 3) % 11,
        1 + (sample * 5 + 1) % 13,
        1 + (sample * 3 + 2) % 7,
      ];
      final target = sample * 17 % 41;
      expect(
        minimumBottleCounts(target, capacities),
        _bruteForce(target, capacities),
        reason: 'target=$target capacities=$capacities',
      );
    }
  });
}
