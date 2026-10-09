import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hex/engine.dart';

/// Bot-vs-bot proof: no stuck states are possible.
/// Every game must terminate with exactly one winner, a valid winning chain,
/// and never exceed size*size moves (draws are impossible in Hex).
HexEngine _playBotGame({
  required int size,
  required int difficulty,
  required bool pie,
  required Random rnd,
}) {
  final e = HexEngine(size: size, pieRuleEnabled: pie);
  addTearDown(e.dispose);
  final ai = HexAI();
  var guard = 0;
  while (!e.over) {
    // A stuck engine would spin here forever; the guard turns that into a
    // loud test failure instead.
    assert(++guard <= size * size + 5, 'STUCK: game did not terminate');
    if (guard > size * size + 5) {
      throw StateError('STUCK: game did not terminate');
    }
    if (e.canSwap) {
      // Random swap policy exercises both branches of the pie rule.
      if (rnd.nextBool()) {
        expect(e.swap(), isTrue);
      } else {
        e.declineSwap();
      }
      continue;
    }
    final mv = ai.chooseMove(e, e.turn, difficulty, timeBudgetMs: 100);
    expect(mv[0] >= 0 && mv[1] >= 0, isTrue,
        reason: 'AI must always find a legal move (size=$size)');
    expect(e.play(mv[0], mv[1]), isTrue,
        reason: 'AI move $mv must be legal (size=$size)');
  }
  return e;
}

bool _adjacent(List<int> a, List<int> b) {
  for (final d in HexEngine.dirs) {
    if (a[0] + d[0] == b[0] && a[1] + d[1] == b[1]) return true;
  }
  return false;
}

/// Validate the winning chain: every cell belongs to the winner, consecutive
/// cells share a side, and the chain touches both of the winner's edges.
/// Path is stored goal-edge -> start-edge.
void _validateResult(HexEngine e) {
  expect(e.over, isTrue);
  expect(e.winner, anyOf(0, 1));
  final p = e.winner!;
  final path = e.winPath;
  expect(path, isNotNull);
  expect(path, isNotEmpty);
  final n = e.size;
  bool isStart(int q, int r) => p == 0 ? r == 0 : q == 0;
  bool isGoal(int q, int r) => p == 0 ? r == n - 1 : q == n - 1;
  for (final c in path!) {
    expect(e.board[c[0]][c[1]], p, reason: 'chain cell $c not winner $p');
  }
  for (int i = 0; i < path.length - 1; i++) {
    expect(_adjacent(path[i], path[i + 1]), isTrue,
        reason: 'chain cells ${path[i]} and ${path[i + 1]} not adjacent');
  }
  expect(isGoal(path.first[0], path.first[1]), isTrue,
      reason: 'chain must touch the goal edge');
  expect(isStart(path.last[0], path.last[1]), isTrue,
      reason: 'chain must touch the start edge');
  // The loser must NOT also have a chain (exactly one winner).
  expect(e.winPathFor(1 - p), isNull,
      reason: 'loser must not have a winning chain');
  expect(e.moveCount, lessThanOrEqualTo(n * n));
}

void main() {
  for (final size in [7, 9, 11]) {
    for (final diff in [0, 1]) {
      test('bot-vs-bot size=$size diff=$diff pie=on: terminates, one winner',
          () {
        final rnd = Random(1234 + size * 10 + diff);
        for (int g = 0; g < 6; g++) {
          _validateResult(_playBotGame(
              size: size, difficulty: diff, pie: true, rnd: rnd));
        }
      });
      test('bot-vs-bot size=$size diff=$diff pie=off: terminates, one winner',
          () {
        final rnd = Random(777 + size * 10 + diff);
        for (int g = 0; g < 4; g++) {
          _validateResult(_playBotGame(
              size: size, difficulty: diff, pie: false, rnd: rnd));
        }
      });
    }
  }

  test('master bot-vs-bot 7x7 terminates with one winner', () {
    final rnd = Random(42);
    for (int g = 0; g < 2; g++) {
      _validateResult(
          _playBotGame(size: 7, difficulty: 2, pie: true, rnd: rnd));
    }
  });

  test('13x13 gentle bot-vs-bot terminates', () {
    final rnd = Random(9);
    _validateResult(
        _playBotGame(size: 13, difficulty: 0, pie: true, rnd: rnd));
  });

  test('full board always holds exactly one winner (draws impossible)', () {
    for (int seed = 0; seed < 10; seed++) {
      final rnd = Random(seed);
      final e = HexEngine(size: 7, pieRuleEnabled: false);
      addTearDown(e.dispose);
      for (int q = 0; q < 7; q++) {
        for (int r = 0; r < 7; r++) {
          e.board[q][r] = rnd.nextInt(2);
        }
      }
      final t = e.winPathFor(0) != null;
      final i = e.winPathFor(1) != null;
      expect(t ^ i, isTrue,
          reason: 'seed $seed: full board must have exactly one winner');
    }
  });

  test('watchdog recovers a dead ai-thinking phase', () async {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    addTearDown(e.dispose);
    e.configure(
        bots: const [false, true],
        difficulty: 0,
        thinkDelay: const Duration(milliseconds: 20));
    e.begin();
    expect(e.phase, HexPhase.awaitingMove);
    expect(e.humanPlay(3, 3), isTrue);
    expect(e.phase, HexPhase.settling);
    e.debugDropTimer(); // simulate the phase timer dying without progress
    e.recover(); // watchdog tick
    expect(e.phase, HexPhase.aiThinking); // bot turn re-armed
    await Future.delayed(const Duration(milliseconds: 600));
    expect(e.moveCount, 2); // the bot placed its tile visibly
    expect(e.phase, HexPhase.awaitingMove);
  });

  test('watchdog never disturbs a human turn', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    addTearDown(e.dispose);
    e.begin();
    e.debugDropTimer();
    e.recover();
    expect(e.phase, HexPhase.awaitingMove);
    expect(e.moveCount, 0);
  });

  test('bot swap decision runs through the director', () async {
    final e = HexEngine(size: 7, pieRuleEnabled: true);
    addTearDown(e.dispose);
    e.configure(
        bots: const [false, true],
        difficulty: 1,
        thinkDelay: const Duration(milliseconds: 20));
    e.begin();
    expect(e.humanPlay(3, 3), isTrue); // strong central opening
    await Future.delayed(const Duration(milliseconds: 1200));
    expect(e.swapAvailable, isFalse); // window resolved by the bot
    expect(e.swapUsed, isTrue); // central stone -> bot takes the swap
    expect(e.moveCount, 1);
    expect(e.phase, HexPhase.awaitingMove); // human (now indigo) to move
  });
}
