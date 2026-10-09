import 'package:flutter_test/flutter_test.dart';
import 'package:hex/engine.dart';

void main() {
  test('opening move offers swap', () {
    final e = HexEngine(size: 11);
    expect(e.play(5, 5), isTrue);
    expect(e.canSwap, isTrue);
    expect(e.turn, 1);
  });

  test('swap accepted flips colors and passes turn', () {
    final e = HexEngine(size: 11);
    e.play(5, 5);
    expect(e.swap(), isTrue);
    expect(e.board[5][5], 0); // tile kept, now belongs to (new) terracotta
    expect(e.swapUsed, isTrue);
    expect(e.canSwap, isFalse);
    expect(e.turn, 1); // new indigo (old terracotta) to move
    expect(e.undo(5), 0); // cannot undo across the swap
  });

  test('swap declined expires forever', () {
    final e = HexEngine(size: 11);
    e.play(5, 5);
    e.declineSwap();
    expect(e.canSwap, isFalse);
    expect(e.play(0, 1), isTrue);
    expect(e.canSwap, isFalse);
    expect(e.swap(), isFalse); // late swap rejected
  });

  test('illegal overwrite rejected, turn unchanged', () {
    final e = HexEngine(size: 11);
    e.play(5, 5);
    e.declineSwap();
    expect(e.play(5, 5), isFalse);
    expect(e.turn, 1);
    expect(e.moveCount, 2 - 1); // only the opening move counted
  });

  test('terracotta vertical win on 7x7', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    // Terracotta column q=3 from r=0..6, indigo plays elsewhere.
    for (int r = 0; r < 7; r++) {
      expect(e.play(3, r), isTrue); // terracotta
      if (r < 6) expect(e.play(0, r), isTrue); // indigo filler
    }
    expect(e.over, isTrue);
    expect(e.winner, 0);
    expect(e.winPath, isNotNull);
    expect(e.winPath!.length, 7);
  });

  test('indigo horizontal win', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    for (int q = 0; q < 7; q++) {
      expect(e.play(q, 0), isTrue); // terracotta filler (row can't connect)
      expect(e.play(q, 3), isTrue); // indigo row r=3
    }
    expect(e.over, isTrue);
    expect(e.winner, 1);
  });

  test('corner tile alone does not win', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    e.play(0, 0); // corner touches both terracotta edges but isolated
    expect(e.over, isFalse);
  });

  test('vertex-touching tiles do not connect', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    // (0,0) and (1,1) touch at a vertex only, not a side.
    e.board[0][0] = 0;
    e.board[1][1] = 0;
    expect(e.winPathFor(0), isNull);
  });

  test('AI takes immediate win (steady)', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    final ai = HexAI();
    // Indigo (AI) one move from completing row r=3.
    for (int q = 0; q < 6; q++) {
      e.board[q][3] = 1;
      e.history.add([q, 3]);
    }
    e.turn = 1;
    final mv = ai.chooseMove(e, 1, 1);
    // Any winning cell is correct: (6,3) completes the row, (6,2)/(6,4)
    // touch the right edge while bridging to the chain.
    e.board[mv[0]][mv[1]] = 1;
    expect(e.winPathFor(1), isNotNull, reason: 'AI move $mv should win');
  });

  test('AI blocks immediate loss (steady)', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    final ai = HexAI();
    // Terracotta column hugging the left edge, one cell short: the ONLY
    // immediate winning cell is (0,6).
    for (int r = 0; r < 6; r++) {
      e.board[0][r] = 0;
      e.history.add([0, r]);
    }
    e.turn = 1;
    final mv = ai.chooseMove(e, 1, 1);
    expect(mv, [0, 6]);
    // The real block: AI stone there must leave terracotta no immediate win.
    e.board[mv[0]][mv[1]] = 1;
    var foeWins = false;
    for (final c in e.emptyCells()) {
      e.board[c[0]][c[1]] = 0;
      if (e.winPathFor(0) != null) foeWins = true;
      e.board[c[0]][c[1]] = -1;
    }
    expect(foeWins, isFalse,
        reason: 'block $mv must stop all immediate terracotta wins');
  });

  test('undo in vs-AI removes two plies, respects floor', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    e.play(3, 3); // H
    e.play(0, 0); // A
    e.play(3, 4); // H
    expect(e.turn, 1);
    expect(e.undo(2), 2);
    expect(e.board[0][0], -1);
    expect(e.board[3][4], -1);
    expect(e.turn, 1); // human (terracotta) to move... turn was 1 (AI); after removing 2 -> 1? 
  });

  test('resignation gives opponent the win', () {
    final e = HexEngine(size: 7, pieRuleEnabled: false);
    e.play(3, 3);
    e.resign(0);
    expect(e.over, isTrue);
    expect(e.winner, 1);
    expect(e.resigned, isTrue);
  });

  test('JSON round-trip preserves exact state (pause/kill-restore)', () {
    final e = HexEngine(size: 9);
    e.play(4, 4);
    e.declineSwap();
    e.play(0, 1);
    e.play(4, 5);
    final r = HexEngine.fromJson(e.toJson());
    expect(r.size, 9);
    expect(r.turn, e.turn);
    expect(r.moveCount, 3);
    expect(r.board[4][4], 0);
    expect(r.board[0][1], 1);
    expect(r.swapAvailable, isFalse);
    expect(r.undo(2), 2);
  });

  test('AI swap takes strong central opening', () {
    final e = HexEngine(size: 11);
    final ai = HexAI();
    e.play(5, 5);
    expect(ai.shouldSwap(e, [5, 5]), isTrue);
    expect(ai.shouldSwap(e, [0, 0]), isFalse);
  });
}
