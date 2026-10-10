// Sequence mission logic: tap shuffled number tiles in exact order.
//
// Each execution draws distinct numbers (1..99), shuffles their display
// positions, and picks the required direction (ascending or descending)
// fresh from the injected [Random], so seeded tests are deterministic.
// Rules:
//   - Tiles must be tapped in the exact prompted order; correct taps
//     lock in and highlight.
//   - A wrong tap resets all progress ([lastAttemptWrong] raised so the
//     UI can show the hint); the layout and direction stay put.
// The mission completes when every tile is tapped in order.

import 'dart:math' show Random;

import 'package:flutter/foundation.dart';

import '../mission_config.dart';

/// Required tap direction for one sequence execution.
enum SequenceDirection {
  ascending,
  descending,
}

/// Owns one sequence mission's progress; see the file docs.
class SequenceMissionController extends ChangeNotifier {
  SequenceMissionController({
    required SequenceMissionConfig config,
    required Random random,
  })  : direction =
            random.nextBool() ? SequenceDirection.ascending : SequenceDirection.descending,
        _tiles = _deal(config.difficulty.tileCount, random);

  /// Display-order tiles (shuffled; fixed for the execution).
  final List<int> _tiles;

  /// Required direction, drawn at construction.
  final SequenceDirection direction;

  int _progress = 0;
  bool _wrong = false;
  bool _done = false;

  /// Tiles in display order.
  List<int> get tiles => _tiles;

  /// Correct taps so far (a prefix of the solution).
  int get progress => _progress;

  int get total => _tiles.length;

  /// True after a wrong tap, until the next tap.
  bool get lastAttemptWrong => _wrong;

  bool get isDone => _done;

  /// Whether the tile at display [index] is already locked in.
  bool isFound(int index) {
    final List<int> solution = _solution();
    final int value = _tiles[index];
    for (int i = 0; i < _progress; i++) {
      if (solution[i] == value) {
        return true;
      }
    }
    return false;
  }

  /// Draws [tileCount] distinct numbers (1..99) in shuffled order.
  static List<int> _deal(int tileCount, Random random) {
    final List<int> pool =
        List<int>.generate(99, (int i) => i + 1)..shuffle(random);
    final List<int> tiles = pool.take(tileCount).toList()
      ..shuffle(random);
    return tiles;
  }

  /// Required tap order for the drawn direction.
  List<int> _solution() {
    final List<int> ordered = List<int>.of(_tiles)..sort();
    return direction == SequenceDirection.ascending
        ? ordered
        : ordered.reversed.toList();
  }

  /// Taps the tile at display [index] per the file-docs rules.
  /// Out-of-range indices, already-found tiles, and calls after [isDone]
  /// are no-ops.
  void tap(int index) {
    if (_done || index < 0 || index >= _tiles.length) {
      return;
    }
    if (isFound(index)) {
      return;
    }
    final List<int> solution = _solution();
    if (_tiles[index] == solution[_progress]) {
      _wrong = false;
      _progress++;
      if (_progress >= _tiles.length) {
        _done = true;
      }
    } else {
      _wrong = true;
      _progress = 0;
    }
    notifyListeners();
  }
}
