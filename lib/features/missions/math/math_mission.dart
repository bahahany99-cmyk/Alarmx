// Math mission logic (Phase 4): deterministic question generation,
// answer checking, and mission progress.
//
// Generation, validation, and state are separated so tests stay
// deterministic: [MathQuestionGenerator] draws from an injected [Random]
// (tests pass a seeded one), [checkMathAnswer] is a pure function, and
// [MathMissionController] owns index/attempt/completion state. Widgets
// only render a controller.

import 'dart:math' show Random;

import 'package:flutter/foundation.dart';

import '../mission_config.dart';

/// Operators used in generated questions.
enum MathOperator {
  add,
  subtract,
  multiply,
  divide,
}

/// One generated question with its exact integer answer.
class MathQuestion {
  const MathQuestion({
    required this.a,
    required this.b,
    required this.operator,
  });

  final int a;
  final int b;
  final MathOperator operator;

  /// Exact answer. Division questions are generated with an exact
  /// quotient, so truncating division is exact here by construction.
  int get answer {
    switch (operator) {
      case MathOperator.add:
        return a + b;
      case MathOperator.subtract:
        return a - b;
      case MathOperator.multiply:
        return a * b;
      case MathOperator.divide:
        return a ~/ b;
    }
  }

  /// Renders `a <op> b = ?` for display.
  String display() {
    final String symbol = switch (operator) {
      MathOperator.add => '+',
      MathOperator.subtract => '-',
      MathOperator.multiply => '×',
      MathOperator.divide => '÷',
    };
    return '$a $symbol $b = ?';
  }
}

/// Generates questions from an injected random source.
///
/// Difficulty shapes (all operands positive, subtraction never negative,
/// division always exact):
///   - easy: + and - within 1..20.
///   - medium: + and - within 1..100, × within 2..12.
///   - hard: multi-digit + and - (both operands 10..200), × with a
///     multi-digit factor (12..25 × 3..12), and exact ÷ with a multi-digit
///     dividend (divisor 3..12, quotient 12..49). Hard sets also
///     guarantee operator variety: with 4+ questions every operator
///     appears at least once; shorter sets use distinct operators.
///     Shuffling draws from the injected [Random], so seeded tests stay
///     deterministic.
class MathQuestionGenerator {
  MathQuestionGenerator(this._random);

  final Random _random;

  /// Generates exactly [config.questionCount] questions.
  List<MathQuestion> generate(MathMissionConfig config) {
    if (config.difficulty != MathDifficulty.hard) {
      return List<MathQuestion>.generate(
        config.questionCount,
        (_) => _next(config.difficulty),
      );
    }
    return _generateHard(config.questionCount);
  }

  /// Hard set with guaranteed operator variety; see the class docs.
  List<MathQuestion> _generateHard(int count) {
    final List<MathOperator> operators = <MathOperator>[
      MathOperator.add,
      MathOperator.subtract,
      MathOperator.multiply,
      MathOperator.divide,
    ]..shuffle(_random);
    while (operators.length < count) {
      operators.add(
        MathOperator.values[_random.nextInt(MathOperator.values.length)],
      );
    }
    final List<MathOperator> picked =
        operators.take(count).toList()..shuffle(_random);
    return <MathQuestion>[
      for (final MathOperator operator in picked) _nextHard(operator),
    ];
  }

  /// One hard question for [operator]; see the class docs for ranges.
  MathQuestion _nextHard(MathOperator operator) {
    switch (operator) {
      case MathOperator.add:
        return MathQuestion(
          a: _range(10, 200),
          b: _range(10, 200),
          operator: MathOperator.add,
        );
      case MathOperator.subtract:
        return _nonNegativeSubtraction(10, 200);
      case MathOperator.multiply:
        return MathQuestion(
          a: _range(12, 25),
          b: _range(3, 12),
          operator: MathOperator.multiply,
        );
      case MathOperator.divide:
        final int divisor = _range(3, 12);
        final int quotient = _range(12, 49);
        return MathQuestion(
          a: divisor * quotient,
          b: divisor,
          operator: MathOperator.divide,
        );
    }
  }

  MathQuestion _next(MathDifficulty difficulty) {
    switch (difficulty) {
      case MathDifficulty.easy:
        if (_random.nextBool()) {
          return MathQuestion(
            a: _range(1, 20),
            b: _range(1, 20),
            operator: MathOperator.add,
          );
        }
        return _nonNegativeSubtraction(1, 20);
      case MathDifficulty.medium:
        final int pick = _random.nextInt(3);
        if (pick == 0) {
          return MathQuestion(
            a: _range(1, 100),
            b: _range(1, 100),
            operator: MathOperator.add,
          );
        }
        if (pick == 1) {
          return _nonNegativeSubtraction(1, 100);
        }
        return MathQuestion(
          a: _range(2, 12),
          b: _range(2, 12),
          operator: MathOperator.multiply,
        );
      case MathDifficulty.hard:
        // Unreachable: hard sets go through [_generateHard].
        return _nextHard(
          MathOperator.values[_random.nextInt(MathOperator.values.length)],
        );
    }
  }

  MathQuestion _nonNegativeSubtraction(int min, int max) {
    final int a = _range(min, max);
    final int b = _range(min, max);
    return MathQuestion(
      a: a >= b ? a : b,
      b: a >= b ? b : a,
      operator: MathOperator.subtract,
    );
  }

  int _range(int min, int max) => min + _random.nextInt(max - min + 1);
}

/// Checks an answer: the trimmed input must parse as an integer and equal
/// the question's exact answer. Anything else (empty, non-numeric, wrong)
/// fails without throwing.
bool checkMathAnswer(MathQuestion question, String input) {
  final int? value = int.tryParse(input.trim());
  return value != null && value == question.answer;
}

/// Owns one math mission's progress: the generated questions, the current
/// index, the last-attempt outcome, and completion.
///
/// A wrong answer keeps the current question and raises
/// [lastAttemptFailed]; the mission completes only when every question in
/// order is answered correctly. [submit] returns `true` exactly when the
/// submission completes the whole mission.
class MathMissionController extends ChangeNotifier {
  MathMissionController({
    required MathMissionConfig config,
    required Random random,
  }) : _questions = MathQuestionGenerator(random).generate(config);

  final List<MathQuestion> _questions;
  int _index = 0;
  bool _failed = false;
  bool _done = false;

  MathQuestion get current => _questions[_index];

  int get index => _index;

  int get total => _questions.length;

  bool get lastAttemptFailed => _failed;

  bool get isDone => _done;

  bool submit(String input) {
    if (_done) {
      return true;
    }
    if (!checkMathAnswer(_questions[_index], input)) {
      _failed = true;
      notifyListeners();
      return false;
    }
    _failed = false;
    if (_index + 1 >= _questions.length) {
      _done = true;
      notifyListeners();
      return true;
    }
    _index++;
    notifyListeners();
    return false;
  }
}
