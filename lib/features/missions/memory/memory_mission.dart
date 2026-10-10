// Memory mission logic: match every pair in the card grid.
//
// The deck holds `difficulty.cardCount` cards (12/24/64) dealt from the
// fixed [kMemoryFaces] pool and shuffled with the injected [Random], so
// seeded tests are deterministic. Rules:
//   - Tapping a face-down, unmatched card reveals it (at most two cards
//     are ever revealed at once).
//   - Two revealed cards with the same face match and stay face-up.
//   - A third tap while two mismatched cards are revealed hides them
//     first, then reveals the new card (no timers: fully deterministic).
//   - [moves] counts completed pair attempts (every second reveal).
// The mission completes when every pair matches.

import 'dart:math' show Random;

import 'package:flutter/foundation.dart';

import '../mission_config.dart';

/// Distinct card faces. Hard deals 32 pairs, so the pool must hold at
/// least 32; 40 leaves headroom.
const List<String> kMemoryFaces = <String>[
  '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
  '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔',
  '🐧', '🐦', '🐤', '🦄', '🐝', '🦋', '🐢', '🐙',
  '🦑', '🦐', '🦞', '🦀', '🐡', '🐬', '🐳', '🐋',
  '🦈', '🐊', '🐅', '🦓', '🐘', '🦛', '🦏', '🐪',
];

/// One dealt card: its face plus which pair it belongs to.
class MemoryCard {
  const MemoryCard({required this.face, required this.pairId});

  final String face;
  final int pairId;
}

/// Owns one memory mission's progress; see the file docs.
class MemoryMissionController extends ChangeNotifier {
  MemoryMissionController({
    required MemoryMissionConfig config,
    required Random random,
  }) : _cards = _deal(config.difficulty.cardCount, random);

  final List<MemoryCard> _cards;
  final List<int> _revealed = <int>[];
  final Set<int> _matchedPairs = <int>{};
  int _moves = 0;
  bool _done = false;

  /// Cards in display order.
  List<MemoryCard> get cards => _cards;

  /// Completed pair attempts.
  int get moves => _moves;

  int get matchedPairs => _matchedPairs.length;

  int get totalPairs => _cards.length ~/ 2;

  bool get isDone => _done;

  bool isRevealed(int index) => _revealed.contains(index);

  bool isMatched(int index) =>
      _matchedPairs.contains(_cards[index].pairId);

  /// Deals [cardCount] cards (each face twice) in shuffled order.
  static List<MemoryCard> _deal(int cardCount, Random random) {
    final int pairs = cardCount ~/ 2;
    final List<MemoryCard> deck = <MemoryCard>[
      for (int pair = 0; pair < pairs; pair++) ...<MemoryCard>[
        MemoryCard(face: kMemoryFaces[pair], pairId: pair),
        MemoryCard(face: kMemoryFaces[pair], pairId: pair),
      ],
    ]..shuffle(random);
    return deck;
  }

  /// Flips the card at [index] per the file-docs rules. Out-of-range
  /// indices, matched/revealed cards, and calls after [isDone] are
  /// no-ops.
  void flip(int index) {
    if (_done || index < 0 || index >= _cards.length) {
      return;
    }
    if (isMatched(index) || _revealed.contains(index)) {
      return;
    }
    if (_revealed.length >= 2) {
      // A pending mismatch hides before the new card reveals.
      _revealed.clear();
    }
    _revealed.add(index);
    if (_revealed.length == 2) {
      _moves++;
      final MemoryCard first = _cards[_revealed[0]];
      final MemoryCard second = _cards[_revealed[1]];
      if (first.pairId == second.pairId) {
        _matchedPairs.add(first.pairId);
        _revealed.clear();
        if (_matchedPairs.length >= totalPairs) {
          _done = true;
        }
      }
    }
    notifyListeners();
  }
}
